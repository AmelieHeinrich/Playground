#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

#define PI 3.14159265359

struct Vertex {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 uv;
    packed_float4 tangent;
};

struct PointLight
{
    float3 Position;
    float Radius;
    float3 Color;
    float Pad;
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

float D_GGX(float NdotH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;

    float denom = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

float G_SchlickGGX(float NdotV, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0; // UE4-style

    return NdotV / (NdotV * (1.0 - k) + k);
}

float G_Smith(float NdotV, float NdotL, float roughness)
{
    return G_SchlickGGX(NdotV, roughness) *
           G_SchlickGGX(NdotL, roughness);
}

float3 F_Schlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float3 EvaluatePBR_PointLight(
    float3 worldPos,   // surface world position
    float3 N,          // surface normal (normalized)
    float3 V,          // view direction (normalized)
    float3 lightPos,   // point light position (world space)
    float3 lightColor, // light radiance (RGB intensity)
    float  lightRadius,
    float3 albedo,
    float  metallic,
    float  roughness
)
{
    // --- Light vector ---
    float3 Lvec = lightPos - worldPos;
    float dist  = length(Lvec);

    // Outside light influence
    if (dist >= lightRadius)
        return float3(0.0);

    float3 L = Lvec / dist;
    float3 H = normalize(V + L);

    // --- Dot products ---
    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);

    if (NdotL <= 0.0 || NdotV <= 0.0)
        return float3(0.0);

    // --- Distance attenuation ---
    // Smooth falloff to zero at radius
    float falloff = saturate(1.0 - (dist / lightRadius));
    falloff = falloff * falloff; // smoother curve

    // Optional inverse-square shaping
    float attenuation = falloff / max(dist * dist, 0.01);

    float3 radiance = lightColor * attenuation;

    // --- Fresnel base reflectivity ---
    float3 F0 = mix(float3(0.04), albedo, metallic);

    // --- Specular BRDF ---
    float  D = D_GGX(NdotH, roughness);
    float  G = G_Smith(NdotV, NdotL, roughness);
    float3 F = F_Schlick(VdotH, F0);

    float3 specular =
        (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);

    // --- Diffuse BRDF ---
    float3 kS = F;
    float3 kD = (1.0 - kS) * (1.0 - metallic);
    float3 diffuse = kD * albedo / PI;

    // --- Final lighting ---
    return (diffuse + specular) * radiance * NdotL;
}


float3 GetMaterialNormal(texture2d<float> normalTexture, float3 vertexNormal, float4 tangent, float2 uv)
{
    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest, address::repeat);
    
    float3 normalSample = normalTexture.sample(textureSampler, uv).rgb * 2.0 - 1.0;
    
    float3 N = normalize(vertexNormal);
    float3 T = normalize(tangent.xyz);
    float3 B = cross(N, T) * tangent.w;
    float3x3 TBN = float3x3(T, B, N);
    
    float3 worldNormal = normalize(TBN * normalSample);
    return worldNormal;
}

vertex VSOutput vs_main(uint vertexID [[vertex_id]],
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

fragment float4 fs_main(
    VSOutput in [[stage_in]],
    constant Constants& constants [[buffer(0)]],
    constant MaterialSettings& material [[buffer(1)]],
    const device PointLight* lights [[buffer(2)]],
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
    float3 color = 0.0f;
    
    int lightCount = min(constants.LightCount, 4096);
    for (int i = 0; i < lightCount; ++i) {
        PointLight l = lights[i];

        color += EvaluatePBR_PointLight(
            in.worldPosition.xyz,
            N,
            V,
            l.Position,
            l.Color,
            l.Radius,
            albedo,
            metallic,
            roughness
        );
    }

    return float4(color, 1.0);
}

