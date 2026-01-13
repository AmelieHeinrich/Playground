#include "common/scene_ab.h"

#include <metal_stdlib>
using namespace metal;

struct VSOutput {
    float4 position [[position]];
    float4 worldPosition;
    float3 normal;
    float2 uv;
    float4 tangent;

    uint objectId [[flat]];
};

struct FSOutput {
    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
    float2 metallicRoughness [[color(2)]];
};

vertex VSOutput gbuffer_vs(uint vertexID [[vertex_id]],
                         uint instanceId [[base_instance]],
                         const device SceneArgumentBuffer& scene [[buffer(0)]])
{
    SceneInstance instance = scene.Instances[instanceId];
    SceneModel model = scene.Models[instance.ModelIndex];
    MeshVertex v = model.Vertices[vertexID];

    VSOutput out;
    out.position = scene.Camera.ViewProjection * float4(float3(v.position), 1.0);
    out.worldPosition = float4(float3(v.position), 1.0);
    out.uv = v.uv;
    out.normal = v.normal;
    out.tangent = v.tangent;
    out.objectId = instanceId;
    return out;
}

fragment FSOutput gbuffer_fs(VSOutput in [[stage_in]],
                             const device SceneArgumentBuffer& scene [[buffer(0)]])
{
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        mip_filter::linear,
        address::repeat,
        lod_clamp(0.0f, MAXFLOAT)
    );
    
    SceneInstance instance = scene.Instances[in.objectId];
    SceneMaterial material = scene.Materials[instance.MaterialIndex];
    float4 albedoSample = material.HasAlbedo ? material.Albedo.sample(textureSampler, in.uv) : 1.0f;
    if (albedoSample.a < 0.25)
        discard_fragment();
    
    float3 N = normalize(in.normal);
    if (material.HasNormal) {
        float3 normalSample = material.Normal.sample(textureSampler, in.uv).rgb;
        normalSample = normalSample * 2.0 - 1.0;

        float3 T = normalize(in.tangent.xyz);
        float3 B = cross(N, T) * in.tangent.w;
        float3x3 TBN = float3x3(T, B, N);

        N = normalize(TBN * normalSample);
    }
    
    float roughness = 0.5;
    float metallic  = 0.0;
    if (material.HasPBR) {
        float3 orm = material.PBR.sample(textureSampler, in.uv).rgb;
        roughness = clamp(orm.g, 0.04, 1.0);
        metallic  = clamp(orm.b, 0.0, 1.0);
    }
    
    FSOutput output;
    output.albedo = albedoSample;
    output.normal = float4(N, 1.0f);
    output.metallicRoughness = float2(metallic, roughness);
    return output;
}
