#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

// Parameters for equirectangular to cubemap conversion
struct SkyLoaderParams {
    uint cubemapSize;
    uint face;
};

// Convert cubemap face coordinates to 3D direction vector
float3 GetCubemapDirection(uint face, float2 uv) {
    // Convert UV from [0,1] to [-1,1]
    float2 st = uv * 2.0 - 1.0;

    float3 dir;

    switch (face) {
        case 0: // +X (right)
            dir = float3(1.0, -st.y, -st.x);
            break;
        case 1: // -X (left)
            dir = float3(-1.0, -st.y, st.x);
            break;
        case 2: // +Y (top)
            dir = float3(st.x, 1.0, st.y);
            break;
        case 3: // -Y (bottom)
            dir = float3(st.x, -1.0, -st.y);
            break;
        case 4: // +Z (front)
            dir = float3(st.x, -st.y, 1.0);
            break;
        case 5: // -Z (back)
            dir = float3(-st.x, -st.y, -1.0);
            break;
        default:
            dir = float3(0.0, 0.0, 1.0);
            break;
    }

    return normalize(dir);
}

// Convert 3D direction to equirectangular UV coordinates
float2 DirectionToEquirectangular(float3 dir) {
    // Spherical coordinates
    // phi = atan2(z, x) -> longitude [-pi, pi]
    // theta = acos(y) -> latitude [0, pi]

    float phi = atan2(dir.z, dir.x);
    float theta = acos(clamp(dir.y, -1.0f, 1.0f));

    // Convert to UV coordinates [0, 1]
    float u = (phi + M_PI_F) / (2.0 * M_PI_F);
    float v = theta / M_PI_F;

    return float2(u, v);
}

kernel void sky_loader(
    texture2d<float, access::sample> equirectangular [[texture(0)]],
    texture2d_array<float, access::write> cubemapFaces [[texture(1)]],
    constant SkyLoaderParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= params.cubemapSize || gid.y >= params.cubemapSize) {
        return;
    }

    // Calculate UV for current pixel (center of pixel)
    float2 uv = (float2(gid) + 0.5) / float(params.cubemapSize);

    // Get 3D direction for this cubemap texel
    float3 direction = GetCubemapDirection(params.face, uv);

    // Convert direction to equirectangular coordinates
    float2 equirectUV = DirectionToEquirectangular(direction);

    // Sample the equirectangular texture with bilinear filtering
    constexpr sampler linearSampler(filter::linear, address::repeat);
    float4 color = equirectangular.sample(linearSampler, equirectUV);

    // Write to the appropriate cubemap face
    cubemapFaces.write(color, gid, params.face);
}
