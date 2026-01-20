#pragma once

#include <simd/matrix_types.h>
#include <simd/simd.h>
#include <Asset/MeshLoader.h>

#include "Light.h"

constexpr int MAX_SCENE_MODELS = 1024;
constexpr int MAX_SCENE_INSTANCES = 2048;
constexpr int MAX_SCENE_MATERIALS = 2048;

struct SceneMaterial
{
    uint64_t AlbedoID;
    uint64_t NormalID;
    uint64_t MetallicRoughnessID;

    bool HasAlbedo;
    bool HasNormal;
    bool HasMetallicRoughness;
};

struct SceneInstance
{
    uint32_t MaterialID;
    uint32_t ModelIndex;
    uint32_t IndexCount;
    uint32_t IndexOffset;

    simd::float3 Min;
    simd::float3 Max;
};

struct SceneModel
{
    uint64_t VertexBufferID;
    uint64_t IndexBufferID;

    uint32_t InstanceOffset;
    uint32_t InstanceCount;
};

struct SceneCamera
{
    simd::float4x4 View;
    simd::float4x4 Projection;
    simd::float4x4 ViewProjection;
    simd::float4x4 InverseView;
    simd::float4x4 InverseProjection;
    simd::float4x4 InverseViewProjection;
    simd::float3 Position;
    float Near;
    float Far;
};

struct SceneArgumentBuffer
{
    uint64_t ModelBufferID;
    uint64_t InstanceBufferID;
    uint64_t MaterialBufferID;
    uint64_t PointLightBufferID;
    uint64_t CameraBufferID;
    uint64_t SceneTLASID;

    uint32_t PointLightCount;
    DirectionalLight DirectionalLight;
};
