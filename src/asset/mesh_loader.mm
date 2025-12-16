#include "mesh_loader.h"
#include "asset/texture_cache.h"
#include "ktx2_loader.h"
#include "metal/device.h"
#include "texture_cache.h"

#include <fs.h>
#include <iostream>

struct L_SubmeshData {
    uint32_t IndexOffset;
    uint32_t IndexCount;
    uint32_t MaterialIndex;
};

struct L_MaterialData {
    char AlbedoPath[256];
    char NormalPath[256];
    char ORMPath[256];
};

struct vec3 {
    float x, y, z;
};

struct L_StaticMeshHeader {
    uint32_t VertexCount;
    uint32_t IndexCount;
    uint32_t VertexFormat;
    uint32_t IndexFormat;
    uint32_t SubmeshCount;
    uint32_t MaterialCount;
    vec3 Min;
    vec3 Max;
    uint32_t SubmeshTableOffset;
    uint32_t MaterialTableOffset;
    uint32_t VBOffset;
    uint32_t VBSize;
    uint32_t IBOffset;
    uint32_t IBSize;
};

// Helper function to convert texture path to .ktx2 format
static std::string ConvertToKTX2Path(const std::string& originalPath)
{
    // Find the last dot in the path
    size_t lastDot = originalPath.find_last_of('.');
    if (lastDot == std::string::npos) {
        // No extension found, just append .ktx2
        return originalPath + ".ktx2";
    }

    // Replace the extension with .ktx2
    return originalPath.substr(0, lastDot) + ".ktx2";
}

// Helper function to make texture path relative to model path
static std::string MakeRelativeTexturePath(const std::string& modelPath, const std::string& texturePath)
{
    // Find the directory of the model file
    size_t lastSlash = modelPath.find_last_of('/');
    if (lastSlash == std::string::npos) {
        // Model is in root, return texture path as-is
        return texturePath;
    }

    // Get the directory path (everything before the last slash)
    std::string modelDir = modelPath.substr(0, lastSlash + 1);

    // Combine model directory with texture path
    return modelDir + texturePath;
}

Model::~Model()
{
    Cleanup();
}

void Model::Cleanup()
{
    // Release textures
    Textures.clear();
    Meshes.clear();
    Materials.clear();
}

bool Model::Load(const std::string& path)
{
    // Load the binary mesh file
    fs::BinaryResult result = fs::LoadBinaryFile(path);
    if (!result.success) {
        NSLog(@"Failed to load model from path: %s, error: %s", path.c_str(), result.error.c_str());
        return false;
    }

    const uint8_t* bytes = result.data.data();
    size_t fileSize = result.data.size();

    // Read header
    if (fileSize < sizeof(L_StaticMeshHeader)) {
        NSLog(@"File too small to contain valid mesh header");
        return false;
    }

    L_StaticMeshHeader header;
    memcpy(&header, bytes, sizeof(L_StaticMeshHeader));

    NSLog(@"Loading mesh: %d vertices, %d indices, %d submeshes, %d materials",
          header.VertexCount, header.IndexCount, header.SubmeshCount, header.MaterialCount);

    // Read submesh data
    L_SubmeshData* submeshData = (L_SubmeshData*)(bytes + header.SubmeshTableOffset);

    // Read material data
    L_MaterialData* materialData = (L_MaterialData*)(bytes + header.MaterialTableOffset);

    // Get vertex and index data pointers
    const Vertex* vertexData = (Vertex*)(bytes + header.VBOffset);
    const uint32_t* indexData = (uint32_t*)(bytes + header.IBOffset);

    // Load textures and build texture array
    Textures.clear();
    std::unordered_map<std::string, int> texturePathToIndex;

    for (uint32_t i = 0; i < header.MaterialCount; i++) {
        // Process albedo texture
        if (materialData[i].AlbedoPath[0] != '\0') {
            std::string albedoPath(materialData[i].AlbedoPath);
            if (texturePathToIndex.find(albedoPath) == texturePathToIndex.end()) {
                int texIndex = (int)Textures.size();
                texturePathToIndex[albedoPath] = texIndex;

                // Convert to .ktx2 format and make relative to model path
                std::string ktx2Path = ConvertToKTX2Path(albedoPath);
                std::string fullPath = MakeRelativeTexturePath(path, ktx2Path);

                MeshTexture tex;
                id<MTLTexture> mtlTexture = TextureCache::GetTexture(fullPath);
                if (mtlTexture) {
                    tex.Texture = Texture(mtlTexture);
                    Textures.push_back(tex);
                } else {
                    NSLog(@"Failed to load albedo texture: %s", fullPath.c_str());
                    // Still add a null entry to maintain indices
                    Textures.push_back(tex);
                }
            }
        }

        // Process normal texture
        if (materialData[i].NormalPath[0] != '\0') {
            std::string normalPath(materialData[i].NormalPath);
            if (texturePathToIndex.find(normalPath) == texturePathToIndex.end()) {
                int texIndex = (int)Textures.size();
                texturePathToIndex[normalPath] = texIndex;

                // Convert to .ktx2 format and make relative to model path
                std::string ktx2Path = ConvertToKTX2Path(normalPath);
                std::string fullPath = MakeRelativeTexturePath(path, ktx2Path);

                MeshTexture tex;
                id<MTLTexture> mtlTexture = KTX2Loader::LoadKTX2(fullPath);
                if (mtlTexture) {
                    tex.Texture = Texture(mtlTexture);
                    Textures.push_back(tex);
                } else {
                    NSLog(@"Failed to load normal texture: %s", fullPath.c_str());
                    // Still add a null entry to maintain indices
                    Textures.push_back(tex);
                }
            }
        }

        // Process ORM (PBR) texture
        if (materialData[i].ORMPath[0] != '\0') {
            std::string ormPath(materialData[i].ORMPath);
            if (texturePathToIndex.find(ormPath) == texturePathToIndex.end()) {
                int texIndex = (int)Textures.size();
                texturePathToIndex[ormPath] = texIndex;

                // Convert to .ktx2 format and make relative to model path
                std::string ktx2Path = ConvertToKTX2Path(ormPath);
                std::string fullPath = MakeRelativeTexturePath(path, ktx2Path);

                MeshTexture tex;
                id<MTLTexture> mtlTexture = KTX2Loader::LoadKTX2(fullPath);
                if (mtlTexture) {
                    tex.Texture = Texture(mtlTexture);
                    Textures.push_back(tex);
                } else {
                    NSLog(@"Failed to load ORM texture: %s", fullPath.c_str());
                    // Still add a null entry to maintain indices
                    Textures.push_back(tex);
                }
            }
        }
    }

    // Build materials with texture indices
    Materials.clear();
    Materials.reserve(header.MaterialCount);
    for (uint32_t i = 0; i < header.MaterialCount; i++) {
        MeshMaterial mat;
        mat.AlbedoIndex = -1;
        mat.NormalIndex = -1;
        mat.PBRIndex = -1;

        if (materialData[i].AlbedoPath[0] != '\0') {
            std::string albedoPath(materialData[i].AlbedoPath);
            auto it = texturePathToIndex.find(albedoPath);
            if (it != texturePathToIndex.end()) {
                mat.AlbedoIndex = it->second;
            }
        }

        if (materialData[i].NormalPath[0] != '\0') {
            std::string normalPath(materialData[i].NormalPath);
            auto it = texturePathToIndex.find(normalPath);
            if (it != texturePathToIndex.end()) {
                mat.NormalIndex = it->second;
            }
        }

        if (materialData[i].ORMPath[0] != '\0') {
            std::string ormPath(materialData[i].ORMPath);
            auto it = texturePathToIndex.find(ormPath);
            if (it != texturePathToIndex.end()) {
                mat.PBRIndex = it->second;
            }
        }

        Materials.push_back(mat);
    }

    // Create shared vertex and index buffers for the entire model
    VertexBuffer.Initialize(vertexData, header.VBSize);
    VertexBuffer.SetLabel([NSString stringWithFormat:@"VB %s", path.c_str()]);
    IndexBuffer.Initialize(indexData, header.IBSize);
    IndexBuffer.SetLabel([NSString stringWithFormat:@"IB %s", path.c_str()]);

    // Build submeshes
    Meshes.clear();
    Meshes.reserve(header.SubmeshCount);
    for (uint32_t i = 0; i < header.SubmeshCount; i++) {
        Mesh mesh;
        mesh.VertexOffset = 0; // All submeshes share the same vertex buffer, starting at 0
        mesh.IndexOffset = submeshData[i].IndexOffset;
        mesh.IndexCount = submeshData[i].IndexCount;
        mesh.MaterialIndex = submeshData[i].MaterialIndex;
        Meshes.push_back(mesh);
    }

    NSLog(@"Successfully loaded mesh with %lu submeshes, %lu materials, %lu textures",
          Meshes.size(), Materials.size(), Textures.size());

    return true;
}
