#pragma once

#import <simd/simd.h>
#import <Metal/Metal.h>

#include <vector>
#include <string>
#include <unordered_map>

struct Vertex
{
    simd::float3 position;
    simd::float3 normal;
    simd::float2 uv;
    simd::float4 tangent;
};

struct Mesh
{
    id<MTLBuffer> VertexBuffer;
    id<MTLBuffer> IndexBuffer;

    uint32_t IndexOffset;
    uint32_t IndexCount;
    int MaterialIndex = -1;
};

struct MeshMaterial
{
    int AlbedoIndex = -1;
    int NormalIndex = -1;
    int PBRIndex = -1;
};

struct MeshTexture
{
    id<MTLTexture> Texture;
};

struct Model
{
    std::vector<Mesh> Meshes;
    std::vector<MeshMaterial> Materials;
    std::vector<MeshTexture> Textures;

    Model() = default;
    ~Model();

    bool Load(const std::string& path);

private:
    void Cleanup();
};
