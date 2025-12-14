#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vs_main(uint vertexID [[vertex_id]]) {
    // Hardcoded fullscreen triangle vertices
    // Using a single triangle that covers the entire screen
    const float2 positions[3] = {
        float2(-1.0, -1.0),  // Bottom-left
        float2( 3.0, -1.0),  // Bottom-right (off-screen)
        float2(-1.0,  3.0)   // Top-left (off-screen)
    };

    const float2 texCoords[3] = {
        float2(0.0, 1.0),  // Bottom-left
        float2(2.0, 1.0),  // Bottom-right (off-screen)
        float2(0.0, -1.0)  // Top-left (off-screen)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];

    return out;
}

fragment float4 fs_main(VertexOut in [[stage_in]],
                              texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);

    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    return color;
}
