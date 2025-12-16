#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

#include "common/types.h"
#include "common/math.h"
#include "common/pbr.h"
#include "common/light.h"
#include "common/cluster.h"

struct Vertex {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 uv;
    packed_float4 tangent;
};

struct VSOutput {
    float4 position [[position]];
    float4 worldPosition;
    float3 normal;
    float2 uv;
    float4 tangent;
};

struct Constants {
    float4x4 cameraMatrix;
    float4x4 ViewMatrix;

    float3 cameraPosition;
    int LightCount;
    
    int TileSizePx;
    int NumTilesX;
    int NumTilesY;
    int NumSlicesZ;
    
    int ScreenWidth;
    int ScreenHeight;
    float zNear;
    float zFar;
    
    bool ShowHeatmap;
    float3 Pad2;
};

struct MaterialSettings {
    bool hasAlbedo;
    bool hasNormal;
    bool hasORM;
    bool pad;
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
                        constant Constants* constants [[buffer(0)]],
                        const device Vertex* vertices [[buffer(1)]])
{
    Vertex v = vertices[vertexID];

    VSOutput out;
    out.position = constants->cameraMatrix * float4(float3(v.position), 1.0);
    out.worldPosition = float4(float3(v.position), 1.0);
    out.uv = v.uv;
    out.normal = v.normal;
    out.tangent = v.tangent;
    return out;
}

fragment float4 fplus_fs(
    VSOutput in [[stage_in]],
                         
    constant Constants& constants [[buffer(0)]],
    constant MaterialSettings& material [[buffer(1)]],
    const device PointLight* lights [[buffer(2)]],
    const device uint* lightBins [[buffer(3)]],
    const device uint* lightBinCounts [[buffer(4)]],
                         
    texture2d<float> albedoTexture [[texture(0)]],
    texture2d<float> normalTexture [[texture(1)]],
    texture2d<float> ormTexture [[texture(2)]]
)
{
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        mip_filter::linear,
        address::repeat,
        lod_clamp(0.0f, MAXFLOAT)
    );

    // --- Albedo ---
    float4 albedoSample = material.hasAlbedo
        ? albedoTexture.sample(textureSampler, in.uv)
        : float4(1.0);
#if !IOS
    if (albedoSample.a < 0.25)
        discard_fragment();
#endif

    float3 albedo = albedoSample.rgb;

    // --- Normal ---
    float3 N = normalize(in.normal);

    if (material.hasNormal) {
        float3 normalSample = normalTexture.sample(textureSampler, in.uv).rgb;
        normalSample = normalSample * 2.0 - 1.0;

        float3 T = normalize(in.tangent.xyz);
        float3 B = cross(N, T) * in.tangent.w;
        float3x3 TBN = float3x3(T, B, N);

        N = normalize(TBN * normalSample);
    }

    // --- ORM ---
    float roughness = 0.5;
    float metallic  = 0.0;

    if (material.hasORM) {
        float3 orm = ormTexture.sample(textureSampler, in.uv).rgb;
        roughness = clamp(orm.g, 0.04, 1.0);
        metallic  = clamp(orm.b, 0.0, 1.0);
    }

    // --- View direction ---
    float3 V = normalize(constants.cameraPosition - float3(in.worldPosition.xyz));

    // Get cluster index
    // [[position]] already gives us pixel coordinates directly
    uint pixelX = uint(in.position.x);
    uint pixelY = uint(in.position.y);

    uint tileX = min(pixelX / (uint)constants.TileSizePx, (uint)(constants.NumTilesX - 1));
    uint tileY = min(pixelY / (uint)constants.TileSizePx, (uint)(constants.NumTilesY - 1));
    
    float3 viewPos = (constants.ViewMatrix * in.worldPosition).xyz;
    float depth = -viewPos.z;
    depth = clamp(depth, constants.zNear, constants.zFar);
    
    float logDepth = log(depth / constants.zNear) / log(constants.zFar / constants.zNear);
    logDepth = clamp(logDepth, 0.0f, 0.999999f);
    uint zSlice = (uint)(logDepth * (float)constants.NumSlicesZ);
    
    uint clusterIndex = tileX + tileY * constants.NumTilesX + zSlice * (uint)(constants.NumTilesX * constants.NumTilesY);
    uint clusterCount = (uint)(constants.NumTilesX * constants.NumTilesY * constants.NumSlicesZ);
    clusterIndex = min(clusterIndex, clusterCount - 1);
    
    uint binCount = lightBinCounts[clusterIndex];
    uint binBase = clusterIndex * MAX_LIGHTS_PER_CLUSTER;
    
    ahVec3 color = 0.0f;
    for (uint i = 0; i < binCount; ++i) {
        uint lightIndex = lightBins[binBase + i];
        PointLight l = lights[lightIndex];

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
