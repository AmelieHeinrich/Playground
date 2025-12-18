#include "common/scene_ab.h"

struct Constants {
    int TileSizePx;
    int NumTilesX;
    int NumTilesY;
    int NumSlicesZ;

    int ScreenWidth;
    int ScreenHeight;
    bool ShowHeatmap;
    bool Pad;
};

float3 depth_to_world_position(float2 uv, float depth, const device SceneArgumentBuffer& scene)
{
    float2 ndc = uv * 2.0 - 1.0;
    float4 clipPos = float4(ndc, depth, 1.0);
    clipPos.y *= 1.0;
    
    float4 worldPos = scene.Camera.InverseViewProjection * clipPos;
    worldPos /= worldPos.w;
    return worldPos.xyz;
}

kernel void deferred_cs(uint2 gtid [[thread_position_in_grid]],
                        texture2d<float> depthTexture [[texture(0)]],
                        texture2d<float> albedoTexture [[texture(1)]],
                        texture2d<float> normalTexture [[texture(2)]],
                        texture2d<float> metallicRoughnessTexture [[texture(3)]],
                        const device SceneArgumentBuffer& scene [[buffer(0)]],
                        constant Constants& settings [[buffer(1)]],
                        const device uint* lightBins [[buffer(2)]],
                        const device uint* lightBinCounts [[buffer(3)]])
{
    constexpr sampler textureSampler(
        mag_filter::nearest,
        min_filter::nearest,
        mip_filter::nearest,
        address::repeat,
        lod_clamp(0.0f, MAXFLOAT)
    );
    
    float2 uv = float2(gtid.x, gtid.y) / float2(settings.ScreenWidth, settings.ScreenHeight);
    float depth = depthTexture.sample(textureSampler, uv, 0).r;
    float3 albedo = albedoTexture.sample(textureSampler, uv, 0).rgb;
    float3 N = normalTexture.sample(textureSampler, uv, 0).rgb;
    float2 metallicRoughness = metallicRoughnessTexture.sample(textureSampler, uv, 0).rg;
    float metallic = metallicRoughness.x;
    float roughness = metallicRoughness.y;
    
    float3 worldPos = depth_to_world_position(uv, depth, scene);
    float3 V = normalize(scene.Camera.Position - worldPos);
}
