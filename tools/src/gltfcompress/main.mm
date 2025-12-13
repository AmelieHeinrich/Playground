//
// GLTF Compression Tool
// Standalone utility to convert GLTF/GLB files to compressed mesh format
//

#include "tiny_gltf.h"

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cstring>
#include <cmath>
#include <unordered_map>
#include <cfloat>

// Type definitions
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;

// Math structures
struct vec2 {
    float x, y;
    vec2() : x(0), y(0) {}
    vec2(float s) : x(s), y(s) {}
    vec2(float x, float y) : x(x), y(y) {}
};

struct vec3 {
    float x, y, z;
    vec3() : x(0), y(0), z(0) {}
    vec3(float s) : x(s), y(s), z(s) {}
    vec3(float x, float y, float z) : x(x), y(y), z(z) {}

    vec3 operator+(const vec3& v) const { return vec3(x + v.x, y + v.y, z + v.z); }
    vec3 operator-(const vec3& v) const { return vec3(x - v.x, y - v.y, z - v.z); }
    vec3 operator*(float s) const { return vec3(x * s, y * s, z * s); }
    float length() const { return std::sqrt(x*x + y*y + z*z); }
    vec3 normalize() const { float len = length(); return len > 0 ? *this * (1.0f / len) : *this; }
};

struct vec4 {
    float x, y, z, w;
    vec4() : x(0), y(0), z(0), w(0) {}
    vec4(float s) : x(s), y(s), z(s), w(s) {}
    vec4(float x, float y, float z, float w) : x(x), y(y), z(z), w(w) {}
    vec4(const vec3& v, float w) : x(v.x), y(v.y), z(v.z), w(w) {}
    vec3 xyz() const { return vec3(x, y, z); }
};

struct quat {
    float x, y, z, w;
    quat() : x(0), y(0), z(0), w(1) {}
    quat(float w, float x, float y, float z) : x(x), y(y), z(z), w(w) {}
};

struct mat3 {
    float m[9];
    mat3() { for(int i = 0; i < 9; i++) m[i] = (i % 4 == 0) ? 1.0f : 0.0f; }
    vec3 operator*(const vec3& v) const {
        return vec3(
            m[0]*v.x + m[3]*v.y + m[6]*v.z,
            m[1]*v.x + m[4]*v.y + m[7]*v.z,
            m[2]*v.x + m[5]*v.y + m[8]*v.z
        );
    }
};

struct mat4 {
    float m[16];

    mat4() {
        for(int i = 0; i < 16; i++)
            m[i] = (i % 5 == 0) ? 1.0f : 0.0f;
    }

    mat4(const float* data) {
        memcpy(m, data, 16 * sizeof(float));
    }

    mat4(const double* data) {
        for(int i = 0; i < 16; i++)
            m[i] = static_cast<float>(data[i]);
    }

    vec4 operator*(const vec4& v) const {
        return vec4(
            m[0]*v.x + m[4]*v.y + m[8]*v.z + m[12]*v.w,
            m[1]*v.x + m[5]*v.y + m[9]*v.z + m[13]*v.w,
            m[2]*v.x + m[6]*v.y + m[10]*v.z + m[14]*v.w,
            m[3]*v.x + m[7]*v.y + m[11]*v.z + m[15]*v.w
        );
    }

    mat4 operator*(const mat4& other) const {
        mat4 result;
        for(int row = 0; row < 4; row++) {
            for(int col = 0; col < 4; col++) {
                result.m[col*4 + row] = 0;
                for(int k = 0; k < 4; k++) {
                    result.m[col*4 + row] += m[k*4 + row] * other.m[col*4 + k];
                }
            }
        }
        return result;
    }

    mat3 toMat3() const {
        mat3 result;
        result.m[0] = m[0]; result.m[3] = m[4]; result.m[6] = m[8];
        result.m[1] = m[1]; result.m[4] = m[5]; result.m[7] = m[9];
        result.m[2] = m[2]; result.m[5] = m[6]; result.m[8] = m[10];
        return result;
    }
};

// Math utility functions
inline vec3 minVec3(const vec3& a, const vec3& b) {
    return vec3(std::min(a.x, b.x), std::min(a.y, b.y), std::min(a.z, b.z));
}

inline vec3 maxVec3(const vec3& a, const vec3& b) {
    return vec3(std::max(a.x, b.x), std::max(a.y, b.y), std::max(a.z, b.z));
}

mat4 translate(const mat4& m, const vec3& v) {
    mat4 result = m;
    result.m[12] = m.m[0]*v.x + m.m[4]*v.y + m.m[8]*v.z + m.m[12];
    result.m[13] = m.m[1]*v.x + m.m[5]*v.y + m.m[9]*v.z + m.m[13];
    result.m[14] = m.m[2]*v.x + m.m[6]*v.y + m.m[10]*v.z + m.m[14];
    result.m[15] = m.m[3]*v.x + m.m[7]*v.y + m.m[11]*v.z + m.m[15];
    return result;
}

mat4 scale(const mat4& m, const vec3& v) {
    mat4 result;
    for(int i = 0; i < 4; i++) {
        result.m[i] = m.m[i] * v.x;
        result.m[4+i] = m.m[4+i] * v.y;
        result.m[8+i] = m.m[8+i] * v.z;
        result.m[12+i] = m.m[12+i];
    }
    return result;
}

mat4 quatToMat4(const quat& q) {
    mat4 result;
    float qxx = q.x * q.x;
    float qyy = q.y * q.y;
    float qzz = q.z * q.z;
    float qxz = q.x * q.z;
    float qxy = q.x * q.y;
    float qyz = q.y * q.z;
    float qwx = q.w * q.x;
    float qwy = q.w * q.y;
    float qwz = q.w * q.z;

    result.m[0] = 1.0f - 2.0f * (qyy + qzz);
    result.m[1] = 2.0f * (qxy + qwz);
    result.m[2] = 2.0f * (qxz - qwy);
    result.m[3] = 0.0f;

    result.m[4] = 2.0f * (qxy - qwz);
    result.m[5] = 1.0f - 2.0f * (qxx + qzz);
    result.m[6] = 2.0f * (qyz + qwx);
    result.m[7] = 0.0f;

    result.m[8] = 2.0f * (qxz + qwy);
    result.m[9] = 2.0f * (qyz - qwx);
    result.m[10] = 1.0f - 2.0f * (qxx + qyy);
    result.m[11] = 0.0f;

    result.m[12] = 0.0f;
    result.m[13] = 0.0f;
    result.m[14] = 0.0f;
    result.m[15] = 1.0f;

    return result;
}

mat3 inverseMat3(const mat3& m) {
    float det = m.m[0] * (m.m[4]*m.m[8] - m.m[7]*m.m[5]) -
                m.m[3] * (m.m[1]*m.m[8] - m.m[7]*m.m[2]) +
                m.m[6] * (m.m[1]*m.m[5] - m.m[4]*m.m[2]);

    if (std::abs(det) < 1e-6f) return mat3();

    float invDet = 1.0f / det;
    mat3 result;

    result.m[0] = (m.m[4]*m.m[8] - m.m[7]*m.m[5]) * invDet;
    result.m[3] = (m.m[6]*m.m[5] - m.m[3]*m.m[8]) * invDet;
    result.m[6] = (m.m[3]*m.m[7] - m.m[6]*m.m[4]) * invDet;

    result.m[1] = (m.m[7]*m.m[2] - m.m[1]*m.m[8]) * invDet;
    result.m[4] = (m.m[0]*m.m[8] - m.m[6]*m.m[2]) * invDet;
    result.m[7] = (m.m[6]*m.m[1] - m.m[0]*m.m[7]) * invDet;

    result.m[2] = (m.m[1]*m.m[5] - m.m[4]*m.m[2]) * invDet;
    result.m[5] = (m.m[3]*m.m[2] - m.m[0]*m.m[5]) * invDet;
    result.m[8] = (m.m[0]*m.m[4] - m.m[3]*m.m[1]) * invDet;

    return result;
}

mat3 transposeMat3(const mat3& m) {
    mat3 result;
    for(int i = 0; i < 3; i++) {
        for(int j = 0; j < 3; j++) {
            result.m[j*3 + i] = m.m[i*3 + j];
        }
    }
    return result;
}

// Data structures
struct L_StaticVertex {
    vec3 Position;
    vec3 Normal;
    vec2 UV;
    vec4 Tangent;
};

struct L_SubmeshData {
    u32 IndexOffset;
    u32 IndexCount;
    u32 MaterialIndex;
};

struct L_MaterialData {
    char AlbedoPath[256];
    char NormalPath[256];
    char ORMPath[256];
};

struct L_StaticMeshHeader {
    u32 VertexCount;
    u32 IndexCount;
    u32 VertexFormat;
    u32 IndexFormat;
    u32 SubmeshCount;
    u32 MaterialCount;
    vec3 Min;
    vec3 Max;
    u32 SubmeshTableOffset;
    u32 MaterialTableOffset;
    u32 VBOffset;
    u32 VBSize;
    u32 IBOffset;
    u32 IBSize;
};

// Helper functions
template<typename T>
static std::vector<T> ReadAccessor(const tinygltf::Model& model, const tinygltf::Accessor& accessor)
{
    const auto& view = model.bufferViews[accessor.bufferView];
    const auto& buffer = model.buffers[view.buffer];
    const unsigned char* dataPtr = buffer.data.data() + view.byteOffset + accessor.byteOffset;
    std::vector<T> result(accessor.count);
    size_t stride = accessor.ByteStride(view);
    for (size_t i = 0; i < accessor.count; ++i)
        memcpy(&result[i], dataPtr + i * stride, sizeof(T));
    return result;
}

static void BuildNodeTransforms(const tinygltf::Model& model, int nodeIdx, const mat4& parentTransform,
                               std::unordered_map<int, mat4>& nodeTransforms)
{
    const auto& node = model.nodes[nodeIdx];
    mat4 localTransform;

    if (node.matrix.size() == 16) {
        localTransform = mat4(node.matrix.data());
    } else {
        vec3 translation(0.0f);
        quat rotation(1.0f, 0.0f, 0.0f, 0.0f);
        vec3 scaleVec(1.0f);

        if (node.translation.size() == 3)
            translation = vec3(node.translation[0], node.translation[1], node.translation[2]);
        if (node.rotation.size() == 4)
            rotation = quat(node.rotation[3], node.rotation[0], node.rotation[1], node.rotation[2]);
        if (node.scale.size() == 3)
            scaleVec = vec3(node.scale[0], node.scale[1], node.scale[2]);

        mat4 identity;
        localTransform = translate(identity, translation);
        localTransform = localTransform * quatToMat4(rotation);
        localTransform = scale(localTransform, scaleVec);
    }

    mat4 worldTransform = parentTransform * localTransform;
    nodeTransforms[nodeIdx] = worldTransform;

    for (int childIdx : node.children) {
        BuildNodeTransforms(model, childIdx, worldTransform, nodeTransforms);
    }
}

bool CompressGLTF(const std::string& inputPath, const std::string& outputPath)
{
    tinygltf::TinyGLTF loader;
    tinygltf::Model input;
    std::string err, warn;

    bool ok = false;
    if (inputPath.size() >= 4 && inputPath.substr(inputPath.size() - 4) == ".glb")
        ok = loader.LoadBinaryFromFile(&input, &err, &warn, inputPath);
    else
        ok = loader.LoadASCIIFromFile(&input, &err, &warn, inputPath);

    if (!ok) {
        std::cerr << "Error loading GLTF: " << err << std::endl;
        return false;
    }

    if (!warn.empty()) {
        std::cout << "Warning: " << warn << std::endl;
    }

    // Build node transforms
    std::unordered_map<int, mat4> nodeTransforms;
    if (!input.scenes.empty()) {
        int sceneIndex = input.defaultScene >= 0 ? input.defaultScene : 0;
        const auto& scene = input.scenes[sceneIndex];
        for (int nodeIdx : scene.nodes) {
            mat4 identity;
            BuildNodeTransforms(input, nodeIdx, identity, nodeTransforms);
        }
    }

    // Collect all vertices and indices with transforms applied
    std::vector<L_StaticVertex> allVertices;
    std::vector<u32> allIndices;
    std::vector<L_SubmeshData> submeshes;
    vec3 boundsMin(FLT_MAX);
    vec3 boundsMax(-FLT_MAX);

    // Build mesh-to-node transforms map
    std::unordered_map<int, std::vector<mat4>> meshNodeTransforms;
    for (size_t nodeIdx = 0; nodeIdx < input.nodes.size(); ++nodeIdx) {
        const auto& node = input.nodes[nodeIdx];
        if (node.mesh >= 0) {
            auto it = nodeTransforms.find(nodeIdx);
            if (it != nodeTransforms.end()) {
                meshNodeTransforms[node.mesh].push_back(it->second);
            } else {
                mat4 identity;
                meshNodeTransforms[node.mesh].push_back(identity);
            }
        }
    }

    // Process meshes
    for (size_t meshIdx = 0; meshIdx < input.meshes.size(); ++meshIdx) {
        const auto& mesh = input.meshes[meshIdx];

        mat4 identity;
        std::vector<mat4> transforms = { identity };
        auto transformIt = meshNodeTransforms.find(meshIdx);
        if (transformIt != meshNodeTransforms.end() && !transformIt->second.empty()) {
            transforms = transformIt->second;
        }

        for (const auto& prim : mesh.primitives) {
            for (const auto& transform : transforms) {
                if (prim.attributes.find("POSITION") == prim.attributes.end()) {
                    std::cerr << "Warning: Primitive missing POSITION attribute" << std::endl;
                    continue;
                }

                const auto& posAccessor = input.accessors[prim.attributes.at("POSITION")];
                const auto positions = ReadAccessor<vec3>(input, posAccessor);

                std::vector<vec3> normals;
                if (prim.attributes.count("NORMAL"))
                    normals = ReadAccessor<vec3>(input, input.accessors[prim.attributes.at("NORMAL")]);

                std::vector<vec2> uvs;
                if (prim.attributes.count("TEXCOORD_0"))
                    uvs = ReadAccessor<vec2>(input, input.accessors[prim.attributes.at("TEXCOORD_0")]);

                std::vector<vec4> tangents;
                if (prim.attributes.count("TANGENT"))
                    tangents = ReadAccessor<vec4>(input, input.accessors[prim.attributes.at("TANGENT")]);

                mat3 normalMatrix = transposeMat3(inverseMat3(transform.toMat3()));

                u32 vertexBaseIndex = allVertices.size();
                size_t vertexCount = positions.size();

                // Build vertices with transforms
                for (size_t i = 0; i < vertexCount; ++i) {
                    L_StaticVertex v;
                    vec4 worldPos = transform * vec4(positions[i], 1.0f);
                    v.Position = worldPos.xyz();

                    // Update bounds
                    boundsMin = minVec3(boundsMin, v.Position);
                    boundsMax = maxVec3(boundsMax, v.Position);

                    v.Normal = normals.empty() ? vec3(0, 1, 0) : (normalMatrix * normals[i]).normalize();
                    v.UV = uvs.empty() ? vec2(0) : uvs[i];

                    if (!tangents.empty()) {
                        vec3 transformedTangent = (normalMatrix * tangents[i].xyz()).normalize();
                        v.Tangent = vec4(transformedTangent, tangents[i].w);
                    } else {
                        v.Tangent = vec4(0);
                    }

                    allVertices.push_back(v);
                }

                // Load indices
                if (prim.indices < 0) {
                    std::cerr << "Warning: Primitive missing indices" << std::endl;
                    continue;
                }

                u32 indexBaseOffset = allIndices.size();
                const auto& indexAccessor = input.accessors[prim.indices];
                switch (indexAccessor.componentType) {
                    case TINYGLTF_COMPONENT_TYPE_UNSIGNED_SHORT: {
                        std::vector<u16> u16indices = ReadAccessor<u16>(input, indexAccessor);
                        for (u16 index : u16indices) {
                            allIndices.push_back(vertexBaseIndex + index);
                        }
                        break;
                    }
                    case TINYGLTF_COMPONENT_TYPE_UNSIGNED_INT: {
                        std::vector<u32> indices = ReadAccessor<u32>(input, indexAccessor);
                        for (u32 index : indices) {
                            allIndices.push_back(vertexBaseIndex + index);
                        }
                        break;
                    }
                    default:
                        std::cerr << "Error: Unsupported index type" << std::endl;
                        break;
                }

                // Create submesh entry
                L_SubmeshData submesh;
                submesh.IndexOffset = indexBaseOffset;
                submesh.IndexCount = allIndices.size() - indexBaseOffset;
                submesh.MaterialIndex = prim.material >= 0 ? prim.material : 0;
                submeshes.push_back(submesh);
            }
        }
    }

    // Collect materials
    std::vector<L_MaterialData> materials;
    materials.reserve(input.materials.size());
    for (const auto& mat : input.materials) {
        L_MaterialData m = {};

        // Initialize paths to empty strings
        memset(m.AlbedoPath, 0, sizeof(m.AlbedoPath));
        memset(m.NormalPath, 0, sizeof(m.NormalPath));
        memset(m.ORMPath, 0, sizeof(m.ORMPath));

        // Get albedo texture path
        if (mat.pbrMetallicRoughness.baseColorTexture.index >= 0) {
            int texIndex = mat.pbrMetallicRoughness.baseColorTexture.index;
            if (texIndex < (int)input.textures.size()) {
                const auto& texture = input.textures[texIndex];
                if (texture.source >= 0 && texture.source < (int)input.images.size()) {
                    const std::string& uri = input.images[texture.source].uri;
                    if (!uri.empty()) {
                        strncpy(m.AlbedoPath, uri.c_str(), sizeof(m.AlbedoPath) - 1);
                    }
                }
            }
        }

        // Get normal texture path
        if (mat.normalTexture.index >= 0) {
            int texIndex = mat.normalTexture.index;
            if (texIndex < (int)input.textures.size()) {
                const auto& texture = input.textures[texIndex];
                if (texture.source >= 0 && texture.source < (int)input.images.size()) {
                    const std::string& uri = input.images[texture.source].uri;
                    if (!uri.empty()) {
                        strncpy(m.NormalPath, uri.c_str(), sizeof(m.NormalPath) - 1);
                    }
                }
            }
        }

        // Get ORM (Occlusion-Roughness-Metallic) texture path
        if (mat.pbrMetallicRoughness.metallicRoughnessTexture.index >= 0) {
            int texIndex = mat.pbrMetallicRoughness.metallicRoughnessTexture.index;
            if (texIndex < (int)input.textures.size()) {
                const auto& texture = input.textures[texIndex];
                if (texture.source >= 0 && texture.source < (int)input.images.size()) {
                    const std::string& uri = input.images[texture.source].uri;
                    if (!uri.empty()) {
                        strncpy(m.ORMPath, uri.c_str(), sizeof(m.ORMPath) - 1);
                    }
                }
            }
        }

        materials.push_back(m);
    }

    // Build file structure
    L_StaticMeshHeader header = {};
    header.VertexCount = allVertices.size();
    header.IndexCount = allIndices.size();
    header.VertexFormat = 0; // Standard format
    header.IndexFormat = 0;  // u32
    header.SubmeshCount = submeshes.size();
    header.MaterialCount = materials.size();
    header.Min = boundsMin;
    header.Max = boundsMax;

    // Calculate offsets
    u32 currentOffset = sizeof(L_StaticMeshHeader);

    header.SubmeshTableOffset = currentOffset;
    currentOffset += submeshes.size() * sizeof(L_SubmeshData);

    header.MaterialTableOffset = currentOffset;
    currentOffset += materials.size() * sizeof(L_MaterialData);

    header.VBOffset = currentOffset;
    header.VBSize = allVertices.size() * sizeof(L_StaticVertex);
    currentOffset += header.VBSize;

    header.IBOffset = currentOffset;
    header.IBSize = allIndices.size() * sizeof(u32);
    currentOffset += header.IBSize;

    // Write file
    std::vector<u8> fileData;
    fileData.resize(currentOffset);

    u8* ptr = fileData.data();

    // Header
    memcpy(ptr, &header, sizeof(L_StaticMeshHeader));
    ptr += sizeof(L_StaticMeshHeader);

    // Submesh table
    memcpy(ptr, submeshes.data(), submeshes.size() * sizeof(L_SubmeshData));
    ptr += submeshes.size() * sizeof(L_SubmeshData);

    // Material table
    memcpy(ptr, materials.data(), materials.size() * sizeof(L_MaterialData));
    ptr += materials.size() * sizeof(L_MaterialData);

    // Vertex buffer
    memcpy(ptr, allVertices.data(), header.VBSize);
    ptr += header.VBSize;

    // Index buffer
    memcpy(ptr, allIndices.data(), header.IBSize);

    // Write to file
    std::ofstream outFile(outputPath, std::ios::binary);
    if (!outFile) {
        std::cerr << "Error: Could not open output file: " << outputPath << std::endl;
        return false;
    }

    outFile.write(reinterpret_cast<const char*>(fileData.data()), fileData.size());
    outFile.close();

    std::cout << "Successfully compressed mesh:" << std::endl;
    std::cout << "  Vertices: " << header.VertexCount << std::endl;
    std::cout << "  Indices: " << header.IndexCount << std::endl;
    std::cout << "  Submeshes: " << header.SubmeshCount << std::endl;
    std::cout << "  Materials: " << header.MaterialCount << std::endl;
    std::cout << "  Bounds: [" << boundsMin.x << ", " << boundsMin.y << ", " << boundsMin.z << "] to ["
              << boundsMax.x << ", " << boundsMax.y << ", " << boundsMax.z << "]" << std::endl;
    std::cout << "  Output size: " << fileData.size() << " bytes" << std::endl;

    return true;
}

int main(int argc, char* argv[])
{
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <input.gltf> <output.mesh>" << std::endl;
        std::cerr << "Example: " << argv[0] << " input/model.gltf output/model.mesh" << std::endl;
        return 1;
    }

    std::string inputPath = argv[1];
    std::string outputPath = argv[2];

    std::cout << "GLTF Compression Tool" << std::endl;
    std::cout << "Input: " << inputPath << std::endl;
    std::cout << "Output: " << outputPath << std::endl;
    std::cout << std::endl;

    if (!CompressGLTF(inputPath, outputPath)) {
        std::cerr << "Failed to compress GLTF file" << std::endl;
        return 1;
    }

    return 0;
}
