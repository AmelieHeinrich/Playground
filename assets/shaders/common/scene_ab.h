#ifndef SCENE_AB_H
#define SCENE_AB_H

#include "light.h"

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace raytracing;

struct MeshVertex
{
    packed_float3 position;
    packed_float3 normal;
    packed_float2 uv;
    packed_float4 tangent;
};

struct SceneMaterial
{
    texture2d<float> Albedo;
    texture2d<float> Normal;
    texture2d<float> PBR;

    bool HasAlbedo;
    bool HasNormal;
    bool HasPBR;
};

struct SceneInstance
{
    const device MeshVertex* Vertices;
    const device uint* Indices;
    uint MaterialIndex;
    uint IndexCount;
    uint IndexOffset;
    
    float3 Min;
    float3 Max;
};

struct SceneCamera
{
    float4x4 View;
    float4x4 Projection;
    float4x4 ViewProjection;
    float4x4 InverseView;
    float4x4 InverseProjection;
    float4x4 InverseViewProjection;
    float3 Position;
    float Near;
    float Far;
};

struct SceneArgumentBuffer
{
    const device SceneInstance* Instances;
    const device SceneMaterial* Materials;
    const device PointLight* PointLights;
    const device SceneCamera& Camera;
    instance_acceleration_structure AS;
    
    uint PointLightCount;
};

#endif
