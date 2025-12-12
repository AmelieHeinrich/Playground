#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

struct Vertex {
    packed_float3 position;
    packed_float3 normal;
    packed_float2 uv;
    packed_float4 tangent;
};

struct VSOutput {
    float4 position [[position]];
    float2 uv;
};

struct Constants {
    float4x4 cameraMatrix;
};

vertex VSOutput vs_main(uint vertexID [[vertex_id]],
                        constant Constants* constants [[buffer(0)]],
                        const device Vertex* vertices [[buffer(1)]])
{
    Vertex v = vertices[vertexID];

    VSOutput out;
    out.position = constants->cameraMatrix * float4(float3(v.position), 1.0);
    out.uv = v.uv;
    return out;
}

fragment float4 fs_main(VSOutput in [[stage_in]],
                        texture2d<float> albedoTexture [[texture(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear, address::repeat);
    float4 color = albedoTexture.sample(textureSampler, in.uv);
    if (color.a < 0.25)
        discard_fragment();
    return color;
}
