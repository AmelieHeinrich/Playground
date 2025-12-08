#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

// We’ll output clip-space position + a color
struct VSOutput {
    float4 position [[position]];
    float3 color;
};

struct Constants {
    float4x4 cameraMatrix;
};

vertex VSOutput vs_main(uint vertexID [[vertex_id]],
                        constant Constants* constants [[buffer(0)]])
{
    // Hardcoded triangle vertices in clip space
    float3 positions[3] = {
        float3( 0.0,  0.5, 0.0),   // top
        float3(-0.5, -0.5, 0.0),   // left
        float3( 0.5, -0.5, 0.0)    // right
    };

    // Colors per-vertex (RGB)
    float3 colors[3] = {
        float3(1.0, 0.0, 0.0),     // red
        float3(0.0, 1.0, 0.0),     // green
        float3(0.0, 0.0, 1.0)      // blue
    };

    VSOutput out;
    out.position = constants->cameraMatrix * float4(positions[vertexID], 1.0);
    out.color    = colors[vertexID];
    return out;
}

fragment float4 fs_main(VSOutput in [[stage_in]])
{
    return float4(in.color, 1.0);
}
