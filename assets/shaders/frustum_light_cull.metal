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

// Threadgroup size of 64 threads
constexpr constant uint THREADGROUP_SIZE = 64;
constexpr constant uint LIGHTS_PER_THREAD = 64;

kernel void cull_lights_frustum(uint tid [[thread_position_in_grid]],
                                uint lid [[thread_position_in_threadgroup]],
                                uint gid [[threadgroup_position_in_grid]],
                                constant Constants& constants [[buffer(0)]],
                                const device PointLight* lights [[buffer(1)]],
                                device atomic_uint* visibleCount [[buffer(2)]],
                                device uint* visibleLights [[buffer(3)]])
{
    // Shared memory to collect visible lights locally
    // Maximum possible visible lights per threadgroup: THREADGROUP_SIZE * LIGHTS_PER_THREAD
    threadgroup uint localVisibleLights[THREADGROUP_SIZE * LIGHTS_PER_THREAD];
    threadgroup atomic_uint localCount;

    // First thread initializes local counter
    if (lid == 0) {
        atomic_store_explicit(&localCount, 0, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Each thread processes LIGHTS_PER_THREAD lights
    uint startLight = tid * LIGHTS_PER_THREAD;
    uint endLight = min(startLight + LIGHTS_PER_THREAD, constants.PointLightCount);

    for (uint lightIdx = startLight; lightIdx < endLight; lightIdx++) {
        PointLight light = lights[lightIdx];

        float3 pos = light.Position;
        float radius = light.Radius;
        bool inside = true;

        // Test against all 6 frustum planes
        for (uint i = 0; i < 6; i++) {
            Plane plane = constants.Planes[i];
            float distance = dot(plane.Normal, pos) + plane.Distance;

            if (distance < -radius) {
                inside = false;
                break;
            }
        }

        // If visible, add to local list
        if (inside) {
            uint localIdx = atomic_fetch_add_explicit(&localCount, 1, memory_order_relaxed);
            localVisibleLights[localIdx] = lightIdx;
        }
    }

    // Wait for all threads to finish local culling
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Cooperatively write results to global memory
    uint numLocalVisible = atomic_load_explicit(&localCount, memory_order_relaxed);

    // Each thread writes a portion of the visible lights
    // This distributes the atomic operations across threads
    for (uint i = lid; i < numLocalVisible; i += THREADGROUP_SIZE) {
        uint globalIdx = atomic_fetch_add_explicit(visibleCount, 1, memory_order_relaxed);
        visibleLights[globalIdx] = localVisibleLights[i];
    }
}
