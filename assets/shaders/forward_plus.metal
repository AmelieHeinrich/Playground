#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

#include "common/types.h"
#include "common/math.h"
#include "common/pbr.h"
#include "common/light.h"
#include "common/cluster.h"
#include "common/scene_ab.h"

struct VSOutput {
    float4 position [[position]];
    float4 worldPosition;
    float3 normal;
    float2 uv;
    float4 tangent;

    uint objectId [[flat]];
};

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

// Heatmap color based on light count
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

vertex VSOutput fplus_vs(uint vertexID [[vertex_id]],
                         uint instanceId [[instance_id]],
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

fragment float4 fplus_fs(
    VSOutput in [[stage_in]],
    constant Constants& constants [[buffer(0)]],
    const device SceneArgumentBuffer& scene [[buffer(1)]],
    const device uint* lightBins [[buffer(2)]],
    const device uint* lightBinCounts [[buffer(3)]]
)
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

    // --- Albedo ---
    float4 albedoSample = material.HasAlbedo ? material.Albedo.sample(textureSampler, in.uv) : 1.0f;
    if (albedoSample.a < 0.25)
        discard_fragment();

    float3 albedo = albedoSample.rgb;

    // --- Normal ---
    float3 N = normalize(in.normal);
    if (material.HasNormal) {
        float3 normalSample = material.Normal.sample(textureSampler, in.uv).rgb;
        normalSample = normalSample * 2.0 - 1.0;

        float3 T = normalize(in.tangent.xyz);
        float3 B = cross(N, T) * in.tangent.w;
        float3x3 TBN = float3x3(T, B, N);

        N = normalize(TBN * normalSample);
    }

    // --- ORM ---
    float roughness = 0.5;
    float metallic  = 0.0;

    if (material.HasPBR) {
        float3 orm = material.PBR.sample(textureSampler, in.uv).rgb;
        roughness = clamp(orm.g, 0.04, 1.0);
        metallic  = clamp(orm.b, 0.0, 1.0);
    }

    // --- View direction ---
    float3 V = normalize(scene.Camera.Position - float3(in.worldPosition.xyz));

    // Get cluster index
    // [[position]] already gives us pixel coordinates directly
    uint pixelX = uint(in.position.x);
    uint pixelY = uint(in.position.y);

    uint tileX = min(pixelX / (uint)constants.TileSizePx, (uint)(constants.NumTilesX - 1));
    uint tileY = min(pixelY / (uint)constants.TileSizePx, (uint)(constants.NumTilesY - 1));

    float3 viewPos = (scene.Camera.View * in.worldPosition).xyz;
    float depth = -viewPos.z;
    depth = clamp(depth, scene.Camera.Near, scene.Camera.Far);

    float logDepth = log(depth / scene.Camera.Near) / log(scene.Camera.Far / scene.Camera.Near);
    logDepth = clamp(logDepth, 0.0f, 0.999999f);
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
        
#if 0
        intersection_params params;
        params.accept_any_intersection(true);
        
        ray ray;
        ray.direction = -scene.Sun.Direction;
        ray.origin = in.worldPosition.xyz + N * 0.001;
        ray.min_distance = 0.001;
        ray.max_distance = 1000;
        
        intersection_query<triangle_data, instancing> i;
        i.reset(ray, scene.AS, 0xFF, params);
        
        bool occluded = false;
        while (i.next()) {
            i.commit_triangle_intersection();
            occluded = true;
            break;
        }
        
        if (occluded) sunContribution = 0;
#endif
        
        color += sunContribution;
    }
    
    // Point lights
    for (uint i = 0; i < binCount; ++i) {
        uint lightIndex = lightBins[binBase + i];
        PointLight l = scene.PointLights[lightIndex];

        color += EvaluatePBR_PointLight(
            in.worldPosition.xyz,
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
        return float4(heatmapColor, 1.0f);
    }

    return float4(color, 1.0f);
}
