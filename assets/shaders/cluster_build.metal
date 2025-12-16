#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "common/cluster.h"

struct Constants {
    float zNear;
    float zFar;
    uint Width;
    uint Height;
    
    uint TileSizePixel;
    uint3 Pad;
    
    float4x4 InverseProjection;
};

float4 clip_to_view(float4 clip, Constants constants)
{
    float4 view = constants.InverseProjection * clip;
    view = view / view.w;
    return view;
}

float4 screen_to_view(float4 screen, Constants constants)
{
    float2 texCoord = screen.xy / float2(constants.Width, constants.Height);
    float4 clip = float4(texCoord.x * 2.0 - 1.0, 1.0 - texCoord.y * 2.0, screen.z, screen.w);
    return clip_to_view(clip, constants);
}

float3 line_intersection_to_z_plane(float3 a, float3 b, float zDistance)
{
    float3 normal = float3(0, 0, 1);
    float3 ab = b - a;
    
    float t = (zDistance - dot(normal, a)) / dot(normal, ab);
    float3 result = a + t * ab;
    
    return result;
}

kernel void build_clusters(constant Constants& settings,
                           device Cluster* clusters [[buffer(1)]],
                           uint3 groupId [[threadgroup_position_in_grid]],
                           uint3 numGroups [[threadgroups_per_grid]])
{
    const float3 eyePos = float3(0.0f);
    
    // Per tile variable
    uint tileSizePx = settings.TileSizePixel;
    uint clusterIndex = groupId.x + groupId.y * numGroups.x + groupId.z * (numGroups.x * numGroups.y);
    
    // Min/max in screen space
    float4 maxPointScreenSpace = float4(float2(groupId.x + 1, groupId.y + 1) * tileSizePx, -1.0, 1.0);
    float4 minPointScreenSpace = float4(float2(groupId.xy * tileSizePx), -1.0, 1.0);
    
    // Convert to view spae
    float3 maxPointViewSpace = screen_to_view(maxPointScreenSpace, settings).xyz;
    float3 minPointViewSpace = screen_to_view(minPointScreenSpace, settings).xyz;
    
    // Get near and far values of the cluster
    float ratio = settings.zFar / settings.zNear;
    float tileNear = -settings.zNear * pow(ratio, groupId.z / float(numGroups.z));
    float tileFar = -settings.zNear * pow(ratio, (groupId.z + 1) / float(numGroups.z));
    
    // Find 4 intersection points
    float3 minPointNear = line_intersection_to_z_plane(eyePos, minPointViewSpace, tileNear);
    float3 minPointFar = line_intersection_to_z_plane(eyePos, minPointViewSpace, tileFar);
    float3 maxPointNear = line_intersection_to_z_plane(eyePos, maxPointViewSpace, tileNear);
    float3 maxPointFar = line_intersection_to_z_plane(eyePos, maxPointViewSpace, tileFar);
    
    float3 minPointAABB = min(min(minPointNear, minPointFar), min(maxPointNear, maxPointFar));
    float3 maxPointAABB = max(max(minPointNear, minPointFar), max(maxPointNear, maxPointFar));
    
    // Append
    clusters[clusterIndex].Min = float4(minPointAABB, 0.0);
    clusters[clusterIndex].Max = float4(maxPointAABB, 0.0);
}
