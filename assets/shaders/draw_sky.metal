#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

struct SkyUniforms {
    float4x4 InverseViewProjection;
};

struct SkyVSOutput {
    float4 position [[position]];
    float3 direction;
};

// Hardcoded cube vertices for skybox (36 vertices, 12 triangles)
constant float3 cubeVertices[36] = {
    float3( 1, -1, -1), float3( 1, -1,  1), float3( 1,  1,  1),
    float3( 1, -1, -1), float3( 1,  1,  1), float3( 1,  1, -1),
    float3(-1, -1,  1), float3(-1, -1, -1), float3(-1,  1, -1),
    float3(-1, -1,  1), float3(-1,  1, -1), float3(-1,  1,  1),
    float3(-1,  1, -1), float3( 1,  1, -1), float3( 1,  1,  1),
    float3(-1,  1, -1), float3( 1,  1,  1), float3(-1,  1,  1),
    float3(-1, -1,  1), float3( 1, -1,  1), float3( 1, -1, -1),
    float3(-1, -1,  1), float3( 1, -1, -1), float3(-1, -1, -1),
    float3(-1, -1,  1), float3(-1,  1,  1), float3( 1,  1,  1),
    float3(-1, -1,  1), float3( 1,  1,  1), float3( 1, -1,  1),
    float3( 1, -1, -1), float3( 1,  1, -1), float3(-1,  1, -1),
    float3( 1, -1, -1), float3(-1,  1, -1), float3(-1, -1, -1),
};

vertex SkyVSOutput draw_sky_vs(uint vertexID [[vertex_id]],
                               constant SkyUniforms& uniforms [[buffer(0)]])
{
    float3 position = cubeVertices[vertexID];

    SkyVSOutput out;
    out.direction = position;

    float4 clipPos = uniforms.InverseViewProjection * float4(position, 0.0);
    float4x4 viewProj = uniforms.InverseViewProjection;
    out.position = float4(position.xy, 0.9999, 1.0);
    return out;
}

vertex SkyVSOutput draw_sky_scene_vs(uint vertexID [[vertex_id]],
                                     constant float4x4& viewProjection [[buffer(0)]])
{
    float3 position = cubeVertices[vertexID];

    SkyVSOutput out;
    out.direction = position;

    float4 clipPos = viewProjection * float4(position, 0.0);
    out.position = clipPos.xyww;
    return out;
}

fragment float4 draw_sky_fs(SkyVSOutput in [[stage_in]],
                            texturecube<float> skybox [[texture(0)]])
{
    constexpr sampler skySampler(filter::linear, mip_filter::linear);
    float3 direction = normalize(in.direction);
    float3 color = skybox.sample(skySampler, direction).rgb;
    return float4(color, 1.0);
}
