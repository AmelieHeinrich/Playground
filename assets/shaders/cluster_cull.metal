#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "common/cluster.h"
#include "common/light.h"

#define THREADGROUP_SIZE 64

struct Constants {
    float4x4 ViewMatrix;
};

float sq_dist_point_aabb(float3 point, Cluster cluster)
{
    float sqDist = 0.0f;
    for (int i = 0; i < 3; i++) {
        float v = point[i];
        if (v < cluster.Min[i]) {
            sqDist += (cluster.Min[i] - v) * (cluster.Min[i] - v);
        }
        if (v > cluster.Max[i]) {
            sqDist += (v - cluster.Max[i]) * (v - cluster.Max[i]);
        }
    }

    return sqDist;
}

bool test_sphere_aabb(PointLight light, Cluster cluster, float4x4 viewMatrix)
{
    float radius = light.Radius;
    float3 center = float3(viewMatrix * float4(light.Position, 1.0f));
    float squaredDistance = sq_dist_point_aabb(center, cluster);

    return squaredDistance <= (radius * radius);
}

kernel void cluster_cull_lights(uint clusterId [[threadgroup_position_in_grid]],
                                uint tid       [[thread_index_in_threadgroup]],
                                constant Constants& constants        [[buffer(0)]],
                                const device Cluster* clusters       [[buffer(1)]],
                                const device PointLight* lights      [[buffer(2)]],
                                const device uint* visibleLights     [[buffer(3)]],
                                constant uint& visibleLightCount     [[buffer(4)]],
                                device uint* lightBins               [[buffer(5)]],
                                device uint* lightBinCounts          [[buffer(6)]])
{
    Cluster cluster = clusters[clusterId];

    threadgroup uint localIndices[THREADGROUP_SIZE];
    threadgroup uint localCount;

    if (tid == 0)
        localCount = 0;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint i = tid; i < visibleLightCount; i += THREADGROUP_SIZE) {
        PointLight light = lights[visibleLights[i]];

        // TODO: No atomic fetch? InterlockedAdd != genius.
        if (test_sphere_aabb(light, cluster, constants.ViewMatrix)) {
            uint idx = atomic_fetch_add_explicit(
                (threadgroup atomic_uint*)&localCount,
                1,
                memory_order_relaxed);

            if (idx < MAX_LIGHTS_PER_CLUSTER)
                localIndices[idx] = i;
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Write results
    if (tid == 0) {
        uint count = min(localCount, (uint)MAX_LIGHTS_PER_CLUSTER);
        uint base = clusterId * MAX_LIGHTS_PER_CLUSTER;

        for (uint i = 0; i < count; i++)
            lightBins[base + i] = localIndices[i];

        lightBinCounts[clusterId] = count;
    }
}
