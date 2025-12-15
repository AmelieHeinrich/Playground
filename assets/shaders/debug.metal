#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

struct VertexIn {
    float4 position;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float3 color;
};

struct Constants {
    float4x4 cameraMatrix;
};

vertex VertexOut debug_vs(uint vertexID [[vertex_id]],
                          const device VertexIn* vertices [[buffer(0)]],
                          constant Constants& settings [[buffer(1)]])
{
    VertexIn v = vertices[vertexID];
    
    VertexOut out;
    out.position = settings.cameraMatrix * v.position;
    out.color = v.color.rgb;
    return out;
}

fragment float4 debug_fs(VertexOut input [[stage_in]])
{
    return float4(input.color, 1.0f);
}
