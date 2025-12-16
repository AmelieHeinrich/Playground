#include "cluster_cull.h"
#include "depth_prepass.h"

#include "math/AAPLMath.h"
#include "renderer/light.h"
#include "renderer/resource_io.h"
#include <Metal/Metal.h>

struct ClusterBuildConstants
{
    float zNear;
    float zFar;
    uint Width;
    uint Height;

    uint TileSizePixel;
    simd::uint3 Pad;

    simd::float4x4 InverseProjection;
};

struct FrustumLightCullConstants
{
    Plane Planes[6];
    uint PointLightCount;
};

ClusterCullPass::ClusterCullPass()
{
    // Pipeline
    m_FrustumLightCull.Initialize("cull_lights_frustum");
    m_ClusterBuild.Initialize("build_clusters");
    m_ClusterCull.Initialize("cluster_cull_lights");

    // Cluster buffer
    uint maxWidth = 3840;
    uint maxHeight = 2160;
    uint numTilesX = (maxWidth + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;
    uint numTilesY = (maxHeight + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;

    uint clusterCount = numTilesX * numTilesY * CLUSTER_Z_SLICES;
    
    // Light buffer
    ResourceIO::CreateBuffer(CLUSTER_BUFFER, sizeof(Cluster) * clusterCount);
    ResourceIO::CreateBuffer(CLUSTER_BINS_BUFFER, sizeof(uint) * clusterCount * CLUSTER_MAX_LIGHTS);
    ResourceIO::CreateBuffer(CLUSTER_BIN_COUNTS_BUFFER, sizeof(uint) * clusterCount);
    ResourceIO::CreateBuffer(VISIBLE_LIGHTS_BUFFER, sizeof(uint) * MAX_POINT_LIGHTS);
    ResourceIO::CreateBuffer(VISIBLE_LIGHTS_COUNT_BUFFER, sizeof(uint));
}

void ClusterCullPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& depth = ResourceIO::Get(DEPTH_PREPASS_DEPTH_OUTPUT).Texture;
    Buffer& clusterBuffer = ResourceIO::Get(CLUSTER_BUFFER).Buffer;
    Buffer& clusterBins = ResourceIO::Get(CLUSTER_BINS_BUFFER).Buffer;
    Buffer& clusterBinCounts = ResourceIO::Get(CLUSTER_BIN_COUNTS_BUFFER).Buffer;
    Buffer& visibleLightsBuffer = ResourceIO::Get(VISIBLE_LIGHTS_BUFFER).Buffer;
    Buffer& visibleLightsCountBuffer = ResourceIO::Get(VISIBLE_LIGHTS_COUNT_BUFFER).Buffer;

    constexpr uint tileSizePx = CLUSTER_TILE_SIZE_PX;
    constexpr uint numTilesZ  = CLUSTER_Z_SLICES;

    uint width  = depth.Width();
    uint height = depth.Height();

    uint numTilesX = (width  + tileSizePx - 1) / tileSizePx;
    uint numTilesY = (height + tileSizePx - 1) / tileSizePx;
    uint clusterCount = numTilesX * numTilesY * CLUSTER_Z_SLICES;
    uint lightCount = world.GetLightList().GetPointLightCount();
    
    simd::float4x4 viewMatrix = camera.GetViewMatrix();

    ClusterBuildConstants constants{};
    constants.zNear  = camera.GetNearPlane();
    constants.zFar   = camera.GetFarPlane();
    constants.Width  = width;
    constants.Height = height;
    constants.TileSizePixel = tileSizePx;
    constants.InverseProjection = simd::inverse(camera.GetProjectionMatrix());

    FrustumLightCullConstants frustumLightConstants{};
    frustumLightConstants.PointLightCount = lightCount;
    camera.ExtractPlanes(frustumLightConstants.Planes);

    // Reset light buffer
    BlitEncoder blitEncoder = cmdBuffer.BlitPass(@"Reset Light Buffer");
    blitEncoder.FillBuffer(visibleLightsCountBuffer, 0);
    blitEncoder.End();

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Light Cluster Cull");

    // Cull lights against frustum
    encoder.PushGroup(@"Cull Lights Frustum");
    encoder.SetPipeline(m_FrustumLightCull);
    encoder.SetBytes(&frustumLightConstants, sizeof(FrustumLightCullConstants), 0);
    encoder.SetBuffer(world.GetLightList().GetPointLightBuffer(), 1);
    encoder.SetBuffer(visibleLightsCountBuffer, 2);
    encoder.SetBuffer(visibleLightsBuffer, 3);
    encoder.Dispatch(MTLSizeMake(AlignUp(lightCount, 64), 1, 1), MTLSizeMake(64, 1, 1));
    encoder.PopGroup();

    // Build clusters
    encoder.PushGroup(@"Build Clusters");
    encoder.SetPipeline(m_ClusterBuild);
    encoder.SetBytes(&constants, sizeof(ClusterBuildConstants), 0);
    encoder.SetBuffer(clusterBuffer, 1);
    encoder.Dispatch(
        MTLSizeMake(numTilesX, numTilesY, numTilesZ),
        MTLSizeMake(1, 1, 1)
    );
    encoder.PopGroup();

    // Cull lights
    encoder.PushGroup(@"Cull Clusters");
    encoder.SetPipeline(m_ClusterCull);
    encoder.SetBytes(&viewMatrix, sizeof(viewMatrix), 0);
    encoder.SetBuffer(clusterBuffer, 1);
    encoder.SetBuffer(world.GetLightList().GetPointLightBuffer(), 2);
    encoder.SetBuffer(visibleLightsBuffer, 3);
    encoder.SetBuffer(visibleLightsCountBuffer, 4);
    encoder.SetBuffer(clusterBins, 5);
    encoder.SetBuffer(clusterBinCounts, 6);
    encoder.Dispatch(
        MTLSizeMake(clusterCount, 1, 1),
        MTLSizeMake(64, 1, 1)
    );
    encoder.PopGroup();

    encoder.End();
}
