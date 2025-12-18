#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "common/scene_ab.h"

struct ICBWrapper {
    command_buffer CommandBuffer;
};

struct Plane {
    float3 Normal;
    float Distance;
};

bool test_plane(Plane plane, float3 min, float3 max)
{
    // Select the vertex of the AABB that is most positive
    // in the direction of the plane normal
    float3 p;
    p.x = (plane.Normal.x >= 0.0f) ? max.x : min.x;
    p.y = (plane.Normal.y >= 0.0f) ? max.y : min.y;
    p.z = (plane.Normal.z >= 0.0f) ? max.z : min.z;

    // If the positive vertex is outside, the whole AABB is outside
    return dot(plane.Normal, p) + plane.Distance < 0.0f;
}

bool frustum_cull(constant Plane plane[6], float3 min, float3 max)
{
    for (int i = 0; i < 6; i++) {
        if (test_plane(plane[i], min, max))
            return false;
    }
    return true;
}

kernel void cull_geometry(const device SceneArgumentBuffer& arguments [[buffer(0)]],
                          device ICBWrapper& icb [[buffer(1)]],
                          constant Plane* planes [[buffer(2)]],
                          uint threadID [[thread_position_in_grid]])
{
    uint instanceIndex = threadID;
    SceneInstance instance = arguments.Instances[instanceIndex];
    SceneModel model = arguments.Models[instance.ModelIndex];

    render_command command(icb.CommandBuffer, instanceIndex);
    bool visible = frustum_cull(planes, instance.Min, instance.Max);
    if (visible) {
        command.draw_indexed_primitives<uint>(primitive_type::triangle, instance.IndexCount, model.Indices + instance.IndexOffset, 1, 0, instanceIndex);
    }
}
