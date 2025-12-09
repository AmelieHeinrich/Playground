#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

// We'll output clip-space position + a color + UVs
struct VSOutput {
    float4 position [[position]];
    float2 uv;
};

struct Constants {
    float4x4 cameraMatrix;
};

vertex VSOutput vs_main(uint vertexID [[vertex_id]],
                        constant Constants* constants [[buffer(0)]])
{
    // Hardcoded quad vertices in clip space (two triangles forming a quad)
    float3 positions[6] = {
        // First triangle (bottom-left, bottom-right, top-right)
        float3(-0.5, -0.5, 0.0),   // bottom-left
        float3( 0.5, -0.5, 0.0),   // bottom-right
        float3( 0.5,  0.5, 0.0),   // top-right
        // Second triangle (bottom-left, top-right, top-left)
        float3(-0.5, -0.5, 0.0),   // bottom-left
        float3( 0.5,  0.5, 0.0),   // top-right
        float3(-0.5,  0.5, 0.0)    // top-left
    };

    // UV coordinates for texture sampling
    float2 uvs[6] = {
        float2(0.0, 1.0),          // bottom-left
        float2(1.0, 1.0),          // bottom-right
        float2(1.0, 0.0),          // top-right
        float2(0.0, 1.0),          // bottom-left
        float2(1.0, 0.0),          // top-right
        float2(0.0, 0.0)           // top-left
    };

    VSOutput out;
    out.position = constants->cameraMatrix * float4(positions[vertexID], 1.0);
    out.uv       = uvs[vertexID];
    return out;
}

fragment float4 fs_main(VSOutput in [[stage_in]],
                        texture2d<float> texture [[texture(0)]])
{
    return texture.sample(sampler(), in.uv);
}
