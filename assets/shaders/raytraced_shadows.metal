#include "common/scene_ab.h"
#include "common/math.h"

kernel void rt_shadows_cs(uint2 gtid [[thread_position_in_grid]],
                          texture2d<float, access::write> visibility [[texture(0)]],
                          texture2d<float> depthTexture [[texture(1)]],
                          texture2d<float> normalTexture [[texture(2)]],
                          const device SceneArgumentBuffer& scene [[buffer(0)]])
{
    uint width = visibility.get_width();
    uint height = visibility.get_height();
    if (gtid.x >= width || gtid.y >= height) {
        visibility.write(1, gtid);
        return;
    }
    
    float depth = depthTexture.read(gtid).r;
    if (depth == 1.0f) {
        visibility.write(1, gtid);
        return;
    }
    float3 N = normalTexture.read(gtid).rgb;
    float3 worldPosition = depth_to_world_position(gtid, depth, width, height, scene);
    
    if (dot(N, -scene.Sun.Direction) == 0.0f) {
        visibility.write(0, gtid);
        return;
    }
    
    intersector<triangle_data, instancing> i;
    i.accept_any_intersection(true);
    i.assume_geometry_type(geometry_type::triangle);
    i.assume_identity_transforms(true);
    i.force_opacity(forced_opacity::opaque);
    
    ray ray;
    ray.direction = -scene.Sun.Direction;
    ray.origin = worldPosition + N * 0.001;
    ray.min_distance = 0.001;
    ray.max_distance = 500;
    
    typename intersector<triangle_data, instancing>::result_type result;
    result = i.intersect(ray, scene.AS, 0xFF);
    
    // TODO: Alpha testing
    
    // Check occlusion
    bool occluded = (result.type != intersection_type::none);
    
    if (occluded) visibility.write(0, gtid);
    else visibility.write(1, gtid);
}
