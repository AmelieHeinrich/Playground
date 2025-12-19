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

float3 depth_to_world_position(uint2 pixel, float depth, constant Constants& c,
                               const device SceneArgumentBuffer& scene)
{
    float2 uv = (float2(pixel) + 0.5f) / float2(c.ScreenWidth, c.ScreenHeight);
    
    float2 ndc;
    ndc.x = uv.x * 2.0f - 1.0f;
    ndc.y = (1.0f - uv.y) * 2.0f - 1.0f;
    
    float4 clipPos = float4(ndc, depth, 1.0);
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
    if (gtid.x >= (uint)constants.ScreenWidth || gtid.y >= (uint)constants.ScreenHeight) {
        return;
    }
    
    float depth = depthTexture.read(gtid).r;
    if (depth == 1.0f) {
        dst.write(0.0f, gtid);
        return;
    }
    float3 albedo = albedoTexture.read(gtid).rgb;
    float3 N = normalTexture.read(gtid).rgb;
    float2 metallicRoughness = metallicRoughnessTexture.read(gtid).rg;
    float metallic = metallicRoughness.x;
    float roughness = metallicRoughness.y;

    float3 worldPos = depth_to_world_position(gtid, depth, constants, scene);
    float3 V = normalize(scene.Camera.Position - worldPos);

    uint tileX = min(gtid.x / (uint)constants.TileSizePx, (uint)(constants.NumTilesX - 1));
    uint tileY = min(gtid.y / (uint)constants.TileSizePx, (uint)(constants.NumTilesY - 1));

    float3 viewPos = (scene.Camera.View * float4(worldPos, 1.0f)).xyz;
    float viewDepth = -viewPos.z;
    float logDepth = log(viewDepth / scene.Camera.Near) / log(scene.Camera.Far / scene.Camera.Near);
    
    uint zSlice = (uint)(logDepth * (float)constants.NumSlicesZ);
    uint clusterIndex = tileX + tileY * constants.NumTilesX + zSlice * (uint)(constants.NumTilesX * constants.NumTilesY);
    
    uint binCount = lightBinCounts[clusterIndex];
    uint binBase = clusterIndex * MAX_LIGHTS_PER_CLUSTER;

    ahVec3 color = 0.0f;

    // Directional light
    if (scene.Sun.Enabled) {
        color += EvaluatePBR_DirectionalLight(
            N, V, -scene.Sun.Direction, 
            scene.Sun.Color, scene.Sun.Intensity, 
            albedo, metallic, roughness
        );
    }

    // Heatmap debug visualization (early out)
    if (constants.ShowHeatmap) {
        float3 heatmapColor = GetHeatmapColor(binCount);
        dst.write(float4(heatmapColor, 1.0f), gtid);
        return;
    }

    // Point lights (only if there are any in this cluster)
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

    dst.write(float4(color, 1.0f), gtid);
}
