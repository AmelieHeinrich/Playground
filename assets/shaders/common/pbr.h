#ifndef PBR_METAL_H
#define PBR_METAL_H

#include <metal_stdlib>
using namespace metal;

#include "types.h"
#include "math.h"

ahFloat D_GGX(ahFloat NdotH, ahFloat roughness)
{
    ahFloat a  = roughness * roughness;
    ahFloat a2 = a * a;

    ahFloat denom = (NdotH * NdotH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

ahFloat G_SchlickGGX(ahFloat NdotV, ahFloat roughness)
{
    ahFloat r = roughness + 1.0;
    ahFloat k = (r * r) / 8.0; // UE4-style

    return NdotV / (NdotV * (1.0 - k) + k);
}

ahFloat G_Smith(ahFloat NdotV, ahFloat NdotL, ahFloat roughness)
{
    return G_SchlickGGX(NdotV, roughness) *
           G_SchlickGGX(NdotL, roughness);
}

ahVec3 F_Schlick(ahFloat cosTheta, ahVec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

ahVec3 EvaluatePBR_PointLight(
    float3 worldPos,   // surface world position
    float3 N,          // surface normal (normalized)
    float3 V,          // view direction (normalized)
    float3 lightPos,   // point light position (world space)
    float3 lightColor, // light radiance (RGB intensity)
    float  lightRadius,
    float  lightIntensity,
    float3 albedo,
    float  metallic,
    float  roughness
)
{
    // --- Light vector ---
    ahVec3 Lvec = lightPos - worldPos;
    ahFloat dist  = length(Lvec);

    // Outside light influence
    if (dist >= lightRadius)
        return float3(0.0);

    ahVec3 L = Lvec / dist;
    ahVec3 H = normalize(V + L);

    // --- Dot products ---
    ahFloat NdotL = max(dot(N, L), 0.001);
    ahFloat NdotV = max(dot(N, V), 0.001);
    ahFloat NdotH = max(dot(N, H), 0.001);
    ahFloat VdotH = max(dot(V, H), 0.001);

    // --- Distance attenuation ---
    // Smooth falloff to zero at radius
    ahFloat falloff = saturate(1.0 - (dist / lightRadius));
    falloff = falloff * falloff;

    // Optional inverse-square shaping
    ahFloat attenuation = falloff / max(dist * dist, 0.01);

    ahVec3 radiance = lightColor * attenuation;

    // --- Fresnel base reflectivity ---
    ahVec3 F0 = mix(ahVec3(0.04), albedo, metallic);

    // --- Specular BRDF ---
    ahFloat  D = D_GGX(NdotH, roughness);
    ahFloat  G = G_Smith(NdotV, NdotL, roughness);
    ahVec3 F = F_Schlick(VdotH, F0);

    ahVec3 specular =
        (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);

    // --- Diffuse BRDF ---
    ahVec3 kS = F;
    ahVec3 kD = (1.0 - kS) * (1.0 - metallic);
    ahVec3 diffuse = kD * albedo / PI;

    // --- Final lighting ---
    return (diffuse + specular) * (radiance * lightIntensity) * NdotL;
}

#endif // PBR_METAL_H
