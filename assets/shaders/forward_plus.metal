#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

#include "common/types.h"
#include "common/math.h"
#include "common/pbr.h"
#include "common/light.h"

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

    float3 cameraPosition;
    int LightCount;
};

struct MaterialSettings {
    bool hasAlbedo;
    bool hasNormal;
    bool hasORM;
    bool pad;
};

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
    const device uint* visibleLights [[buffer(3)]],
    const device uint& visibleLightCount [[buffer(4)]],
                         
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
    if (albedoSample.a < 0.25)
        discard_fragment();

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

    // Clamp for safety (and to help the compiler)
    ahVec3 color = 0.0f;
    
    for (uint i = 0; i < visibleLightCount; ++i) {
        PointLight l = lights[visibleLights[i]];

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

    return float4(color, 1.0);
}
