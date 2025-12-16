#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "common/scene_ab.h"

struct ICBWrapper
{
    command_buffer CommandBuffer;
};

kernel void cull_geometry(const device SceneArgumentBuffer& arguments [[buffer(0)]],
                          device ICBWrapper& icb [[buffer(1)]],
                          uint threadID [[thread_position_in_grid]])
{
    uint instanceIndex = threadID;
    SceneInstance instance = arguments.Instances[instanceIndex];

    render_command command(icb.CommandBuffer, instanceIndex);
    bool visible = true;
    if (visible) {
        command.draw_indexed_primitives(primitive_type::triangle, instance.IndexCount, instance.Indices, 1, instance.IndexOffset, 0);
    }
}
