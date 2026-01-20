#include <metal_stdlib>
using namespace metal;

kernel void generate_hiz(texture2d<float> src [[texture(0)]],
                         texture2d<float, access::write> dst [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]])
{
    uint w = dst.get_width();
    uint h = dst.get_height();
    if (gid.x >= w || gid.y >= h)
        return;

    uint2 base = gid * 2;
    uint src_w = src.get_width();
    uint src_h = src.get_height();

    float d0 = src.read(base + uint2(0, 0)).r;
    float d1 = (base.x + 1 < src_w) ? src.read(base + uint2(1, 0)).r : d0;
    float d2 = (base.y + 1 < src_h) ? src.read(base + uint2(0, 1)).r : d0;
    float d3 = (base.x + 1 < src_w && base.y + 1 < src_h) ? src.read(base + uint2(1, 1)).r : d0;

    float hiz = min(min(d0, d1), min(d2, d3));
    dst.write(hiz, gid);
}
