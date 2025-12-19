#include "common/scene_ab.h"
#include "common/cluster.h"
#include "common/types.h"
#include "common/pbr.h"

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

float3 GetHeatmapColor(uint lightCount)
{
    float t = clamp(float(lightCount) / MAX_LIGHTS_PER_CLUSTER, 0.0f, 1.0f);

    // Blue -> Cyan -> Green -> Yellow -> Red heatmap
    if (t < 0.25f) {
        // Blue to Cyan
        float s = t / 0.25f;
        return float3(0.0f, s, 1.0f);
    } else if (t < 0.5f) {
        // Cyan to Green
        float s = (t - 0.25f) / 0.25f;
        return float3(0.0f, 1.0f, 1.0f - s);
    } else if (t < 0.75f) {
        // Green to Yellow
        float s = (t - 0.5f) / 0.25f;
        return float3(s, 1.0f, 0.0f);
    } else {
        // Yellow to Red
        float s = (t - 0.75f) / 0.25f;
        return float3(1.0f, 1.0f - s, 0.0f);
    }
}

kernel void deferred_cs(uint2 gtid [[thread_position_in_grid]],
                        texture2d<float> depthTexture [[texture(0)]],
                        texture2d<float> albedoTexture [[texture(1)]],
                        texture2d<float> normalTexture [[texture(2)]],
                        texture2d<float> metallicRoughnessTexture [[texture(3)]],
                        texture2d<float, access::write> dst [[texture(4)]],
                        const device SceneArgumentBuffer& scene [[buffer(0)]],
                        constant Constants& constants [[buffer(1)]],
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

    float2 uv = float2(gtid.x, gtid.y) / float2(constants.ScreenWidth, constants.ScreenHeight);
    float depth = depthTexture.sample(textureSampler, uv, 0).r;
    float3 albedo = albedoTexture.sample(textureSampler, uv, 0).rgb;
    float3 N = normalTexture.sample(textureSampler, uv, 0).rgb;
    float2 metallicRoughness = metallicRoughnessTexture.sample(textureSampler, uv, 0).rg;
    float metallic = metallicRoughness.x;
    float roughness = metallicRoughness.y;

    float3 worldPos = depth_to_world_position(uv, depth, scene);
    float3 V = normalize(scene.Camera.Position - worldPos);

    uint tileX = min(gtid.x / (uint)constants.TileSizePx, (uint)(constants.NumTilesX - 1));
    uint tileY = min(gtid.y / (uint)constants.TileSizePx, (uint)(constants.NumTilesY - 1));

    float3 viewPos = (scene.Camera.View * float4(worldPos, 1.0f)).xyz;
    float viewDepth = -viewPos.z;

    float logDepth = log(viewDepth / scene.Camera.Near) / log(scene.Camera.Far / scene.Camera.Near);
    uint zSlice = (uint)(logDepth * (float)constants.NumSlicesZ);

    uint clusterIndex = tileX + tileY * constants.NumTilesX + zSlice * (uint)(constants.NumTilesX * constants.NumTilesY);
    uint clusterCount = (uint)(constants.NumTilesX * constants.NumTilesY * constants.NumSlicesZ);
    clusterIndex = min(clusterIndex, clusterCount - 1);

    uint binCount = lightBinCounts[clusterIndex];
    uint binBase = clusterIndex * MAX_LIGHTS_PER_CLUSTER;

    ahVec3 color = 0.0f;

    // Directional light
    if (scene.Sun.Enabled) {
        float3 sunContribution = EvaluatePBR_DirectionalLight(N, V, -scene.Sun.Direction, scene.Sun.Color, scene.Sun.Intensity, albedo, metallic, roughness);
        color += sunContribution; // TODO: Sample shadow map or trace ray
    }

    // Point lights
    for (uint i = 0; i < binCount; ++i) {
        uint lightIndex = lightBins[binBase + i];
        PointLight l = scene.PointLights[lightIndex];

        color += EvaluatePBR_PointLight(
            worldPos,
            N,
            V,
            l.Position,
            l.Color,
            l.Radius,
            l.Intensity,
            albedo,
            metallic,
            roughness
        );
    }

    // Heatmap debug visualization
    if (constants.ShowHeatmap) {
        float3 heatmapColor = GetHeatmapColor(binCount);
        dst.write(float4(heatmapColor, 1.0f), gtid);
        return;
    }

    dst.write(float4(color, 1.0f), gtid);
}
