#ifndef MATH_METAL_H
#define MATH_METAL_H

#define PI 3.14159265358979323846

inline float3 depth_to_world_position(uint2 pixel, float depth, uint width, uint height,
                               const device SceneArgumentBuffer& scene)
{
    float2 uv = (float2(pixel) + 0.5f) / float2(width, height);
    
    float2 ndc;
    ndc.x = uv.x * 2.0f - 1.0f;
    ndc.y = (1.0f - uv.y) * 2.0f - 1.0f;
    
    float4 clipPos = float4(ndc, depth, 1.0);
    float4 worldPos = scene.Camera.InverseViewProjection * clipPos;
    worldPos /= worldPos.w;
    return worldPos.xyz;
}

inline float linearize_depth(float depthNDC, float nearZ, float farZ)
{
    return nearZ * farZ / (farZ - depthNDC * (farZ - nearZ));
}

#endif // MATH_METAL_H
