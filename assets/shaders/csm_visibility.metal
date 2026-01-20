#include "common/scene_ab.h"
#include "common/math.h"

#define SHADOW_CASCADE_COUNT 4

#if defined(IOS)
    #define PCF_KERNEL_SIZE 1
#else
    #define PCF_KERNEL_SIZE 2
#endif

struct Cascade
{
    float Split;
    texture2d<float> Texture;
    float4x4 View;
    float4x4 Projection;
};

float pcf_sample(texture2d<float> shadowMap,
                 sampler s,
                 float4 worldPos,
                 float4x4 view,
                 float4x4 proj,
                 float bias,
                 int kernelSize)
{
    float4 lightSpacePosition = view * worldPos;
    float4 ndcPosition = proj * lightSpacePosition;
    ndcPosition.xyz /= ndcPosition.w;

    float2 shadowUV = ndcPosition.xy * 0.5 + 0.5;
    shadowUV.y = 1.0 - shadowUV.y;

    // Out of bounds check - return lit if outside shadow map
    if (ndcPosition.z < 0.0 || ndcPosition.z > 1.0)
        return 1.0;
    if (shadowUV.x < 0.0 || shadowUV.x > 1.0 || shadowUV.y < 0.0 || shadowUV.y > 1.0)
        return 1.0;

    uint shadowMapSize = shadowMap.get_width();
    float2 texelSize = 1.0 / float2(shadowMapSize, shadowMapSize);

    float shadow = 0.0;
    int sampleCount = 0;

    float currentDepth = ndcPosition.z - bias;

    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            float2 offsetUV = shadowUV + float2(x, y) * texelSize;
            float shadowMapDepth = shadowMap.sample(s, offsetUV).r;
            shadow += (currentDepth <= shadowMapDepth) ? 1.0 : 0.0;
            sampleCount++;
        }
    }
    shadow /= sampleCount;

    return shadow;
}

kernel void csm_visibility(uint2 gtid [[thread_position_in_grid]],
                           const device SceneArgumentBuffer& scene [[buffer(0)]],
                           const device Cascade* cascades [[buffer(1)]],
                           texture2d<float> depthTexture [[texture(0)]],
                           texture2d<float> normalTexture [[texture(1)]],
                           texture2d<float, access::write> dst [[texture(2)]])
{
    constexpr sampler textureSampler(
        filter::nearest,
        address::clamp_to_edge,
        coord::normalized
    );

    int screenWidth = dst.get_width();
    int screenHeight = dst.get_height();
    int shadowMapSize = cascades[0].Texture.get_width();

    float depth = depthTexture.read(gtid).r;
    if (depth == 1.0f) {
        dst.write(1.0f, gtid);
        return;
    }

    float3 N = normalTexture.read(gtid).rgb;
    float3 worldPos = depth_to_world_position(gtid, depth, screenWidth, screenHeight, scene);
    float3 L = -scene.Sun.Direction;

    // Select cascade based on distance to camera
    float distanceToCamera = length(scene.Camera.Position - worldPos.xyz);

    int layer = SHADOW_CASCADE_COUNT - 1;
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        if (distanceToCamera < cascades[i].Split) {
            layer = i;
            break;
        }
    }

    Cascade cascade0 = cascades[layer];
    Cascade cascade1 = cascades[min(layer + 1, SHADOW_CASCADE_COUNT - 1)];

    float texelSize0 = cascade0.Split / shadowMapSize;
    float texelSize1 = cascade1.Split / shadowMapSize;

    float NdotL = max(dot(N, L), 0.0);
    float bias0 = 0.001 + 0.003 * (1.0 - NdotL);
    float bias1 = 0.001 + 0.003 * (1.0 - NdotL);

    float4 worldPosXYZW = float4(worldPos, 1.0f);
    float shadow0 = pcf_sample(cascade0.Texture, textureSampler, worldPosXYZW, cascade0.View, cascade0.Projection, bias0, PCF_KERNEL_SIZE);
    float shadow1 = pcf_sample(cascade1.Texture, textureSampler, worldPosXYZW, cascade1.View, cascade1.Projection, bias1, PCF_KERNEL_SIZE);

    float blendRange = 0.1;
    float blendStart = cascade0.Split * (1.0 - blendRange);
    float blendFactor = saturate((distanceToCamera - blendStart) / (cascade0.Split - blendStart));

    float shadowFactor = mix(shadow0, shadow1, blendFactor);
    dst.write(shadowFactor, gtid);
}
