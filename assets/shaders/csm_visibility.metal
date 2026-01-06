#include "common/scene_ab.h"
#include "common/math.h"

#define SHADOW_CASCADE_COUNT 4

#if defined(IOS)
    #define PCF_KERNEL_SIZE 2
#else
    #define PCF_KERNEL_SIZE 3
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
    
    if (ndcPosition.z > 1.0)
        return 1.0;
    
    uint shadowMapSize = shadowMap.get_width();
    float2 texelSize = 1.0 / float2(shadowMapSize, shadowMapSize);
    
    float shadow = 0.0;
    int sampleCount = 0;
    
    for (int x = -kernelSize; x <= kernelSize; x++) {
        for (int y = -kernelSize; y <= kernelSize; y++) {
            float2 offsetUV = shadowUV + float2(x, y) * texelSize;
            shadow += shadowMap.sample(s, offsetUV, ndcPosition.z - bias).r;
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
        mag_filter::nearest,
        min_filter::nearest,
        mip_filter::nearest,
        address::repeat,
        lod_clamp(0.0f, MAXFLOAT),
        compare_func::less_equal
    );
    
    int screenWidth = dst.get_width();
    int screenHeight = dst.get_height();
    int shadowMapSize = cascades[0].Texture.get_width();
    
    float depth = depthTexture.read(gtid).r;
    if (depth == 1.0f) {
        dst.write(0.0f, gtid);
        return;
    }
    
    float3 N = normalTexture.read(gtid).rgb;
    float3 worldPos = depth_to_world_position(gtid, depth, screenWidth, screenHeight, scene);
    float3 L = -scene.Sun.Direction;
    
    int layer = -1;
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        if (abs(linearize_depth(depth, scene.Camera.Near, scene.Camera.Far)) < cascades[i].Split) {
            layer = i;
            break;
        }
    }
    if (layer == -1) {
        layer = SHADOW_CASCADE_COUNT - 1;
    }
    
    // Calculate shadow cascade
    float distanceToCamera = length(scene.Camera.Position - worldPos.xyz);
    Cascade cascade0 = cascades[layer];
    Cascade cascade1 = cascades[min(layer + 1, SHADOW_CASCADE_COUNT - 1)];
    
    float texelSize0 = cascade0.Split / shadowMapSize;
    float texelSize1 = cascade1.Split / shadowMapSize;
    
    float slopeBias = 0.05;
    float minBias = 0.005;

    float bias0 = max(slopeBias * (1.0 - dot(N, L)), minBias) * texelSize0;
    float bias1 = max(slopeBias * (1.0 - dot(N, L)), minBias) * texelSize1;
    
    float4 worldPosXYZW = float4(worldPos, 1.0f);
    float shadow0 = pcf_sample(cascade0.Texture, textureSampler, worldPosXYZW, cascade0.View, cascade0.Projection, bias0, PCF_KERNEL_SIZE);
    float shadow1 = pcf_sample(cascade1.Texture, textureSampler, worldPosXYZW, cascade1.View, cascade1.Projection, bias1, PCF_KERNEL_SIZE);
    
    float blendRange = 0.1;
    float blendStart = cascade0.Split * (1.0 - blendRange);
    float blendFactor = saturate((distanceToCamera - blendStart) / (cascade0.Split - blendStart));
    
    float shadowFactor = mix(shadow0, shadow1, blendFactor);
    dst.write(shadowFactor, gtid);
}
