#include <metal_stdlib>
using namespace metal;

#include "common/scene_ab.h"
#include "common/math.h"

kernel void ssmirror_reflections_cs(const device SceneArgumentBuffer& scene [[buffer(0)]],
                                    texture2d<float> normalTexture [[texture(0)]],
                                    texture2d<float> zPyramid [[texture(1)]],
                                    texturecube<float> skyTexture [[texture(2)]],
                                    texture2d<float> pbrTexture [[texture(3)]],
                                    texture2d<float> albedoTexture [[texture(4)]],
                                    texture2d<float> inputTexture [[texture(5)]],
                                    texture2d<float, access::write> outputTexture [[texture(6)]],
                                    texture2d<float> hizTexture [[texture(7)]],
                                    uint2 gid [[thread_position_in_grid]])
{
    uint width = inputTexture.get_width(), height = inputTexture.get_height();

    float3 normal = normalTexture.read(gid).xyz;
    float depth = zPyramid.read(gid).x;
    float2 mr = pbrTexture.read(gid).xy;
    float3 albedo = albedoTexture.read(gid).xyz;
    float metallic = mr.r;

    float3 baseColor = inputTexture.read(gid).rgb;

    if (metallic < 0.90f) {
        outputTexture.write(float4(baseColor, 1.0), gid);
        return;
    }

    float3 worldPos = depth_to_world_position(gid, depth, width, height, scene);

    float3 viewDir = normalize(scene.Camera.Position - worldPos.xyz);
    float3 reflectionDir = reflect(-viewDir, normal);

    float NdotV = max(dot(normal, viewDir), 0.0);
    float3 F0 = mix(float3(0.04), albedo, metallic);
    float3 F = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    
    constexpr sampler skySampler(filter::linear, mip_filter::linear);
    float3 skyColor = skyTexture.sample(skySampler, reflectionDir).rgb;
    float3 finalColor = baseColor + skyColor * F;
    outputTexture.write(float4(finalColor, 1.0), gid);
}
