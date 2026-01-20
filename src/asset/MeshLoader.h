#pragma once

#import <simd/simd.h>
#import <Metal/Metal.h>

#include <vector>
#include <string>
#include <unordered_map>

#include "Metal/Buffer.h"
#include "Metal/Texture.h"

struct Vertex
{
    simd::float3 position;
    simd::float3 normal;
    simd::float2 uv;
    simd::float4 tangent;
};

struct Mesh
{
    uint32_t VertexOffset;
    uint32_t IndexOffset;
    uint32_t IndexCount;
    int MaterialIndex = -1;
    simd::float3 Min;
    simd::float3 Max;
};

struct MeshMaterial
{
    int AlbedoIndex = -1;
    int NormalIndex = -1;
    int PBRIndex = -1;
    bool Opaque = true;
};

struct MeshTexture
{
    Texture* Texture;
};

struct Model
{
    Buffer VertexBuffer;
    Buffer IndexBuffer;

    std::vector<Mesh> Meshes;
    std::vector<MeshMaterial> Materials;
    std::vector<MeshTexture> Textures;

    Model() = default;
    ~Model();

    bool Load(const std::string& path);

private:
    void Cleanup();
};
