#include "common/scene_ab.h"

struct VSOutput {
    float4 position [[position]];
    float2 uv;
    uint objectId [[flat]];
};

vertex VSOutput shadow_vs(uint vertexID [[vertex_id]],
                          uint instanceId [[instance_id]],
                          const device SceneArgumentBuffer& scene [[buffer(0)]],
                          const device float4x4& vp [[buffer(1)]])
{
    SceneInstance instance = scene.Instances[instanceId];
    SceneModel model = scene.Models[instance.ModelIndex];
    MeshVertex v = model.Vertices[vertexID];

    VSOutput out;
    out.position = vp * float4(float3(v.position), 1.0);
    out.uv = v.uv;
    out.objectId = instanceId;
    return out;
}

fragment void shadow_fs(VSOutput in [[stage_in]],
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

   float4 albedoSample = material.HasAlbedo ? material.Albedo.sample(textureSampler, in.uv) : 1.0;
   if (albedoSample.a < 0.25)
       discard_fragment();
}
