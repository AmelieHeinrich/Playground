#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "common/light.h"

struct Plane {
    float3 Normal;
    float Distance;
};

struct Constants {
    Plane Planes[6];
    uint PointLightCount;
};

kernel void cull_lights_frustum(uint tid [[thread_position_in_grid]],
                                constant Constants& constants [[buffer(0)]],
                                const device PointLight* lights [[buffer(1)]],
                                device atomic_uint* visibleCount [[buffer(2)]],
                                device uint* visibleLights [[buffer(3)]])
{
    if (tid >= constants.PointLightCount)
        return;
    
    PointLight light = lights[tid];
    
    float3 pos = light.Position;
    float radius = light.Radius;
    bool inside = true;
    
    for (uint i = 0; i < 6; i++) {
        Plane plane = constants.Planes[i];
        float distance = dot(plane.Normal, pos) + plane.Distance;
        
        if (distance < -radius) {
            inside = false;
            break;
        }
    }
    
    if (!inside)
        return;
    
    uint index = atomic_fetch_add_explicit(visibleCount, 1, memory_order_relaxed);
    visibleLights[index] = tid;
}
