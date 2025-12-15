#include "cluster_cull.h"
#include "depth_prepass.h"

#include "renderer/resource_io.h"

struct Constants
{
    float zNear;
    float zFar;
    uint Width;
    uint Height;

    uint TileSizePixel;
    simd::uint3 Pad;

    simd::float4x4 InverseProjection;
};

ClusterCullPass::ClusterCullPass()
{
    // Pipeline
    m_ClusterBuild.Initialize("build_clusters");

    // Cluster buffer
    uint maxWidth = 3840;
    uint maxHeight = 2160;
    uint numTilesX = (maxWidth + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;
    uint numTilesY = (maxHeight + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;

    uint clusterCount = numTilesX * numTilesY * CLUSTER_Z_SLICES;
    Resource& clusterBuffer = ResourceIO::CreateBuffer(CLUSTER_BUFFER, sizeof(Cluster) * clusterCount);
}

void ClusterCullPass::Render(CommandBuffer& cmdBuffer,
                            World& world,
                            Camera& camera)
{
    Texture& depth = ResourceIO::Get(DEPTH_PREPASS_DEPTH_OUTPUT).Texture;
    Buffer& clusterBuffer = ResourceIO::Get(CLUSTER_BUFFER).Buffer;

    constexpr uint tileSizePx = CLUSTER_TILE_SIZE_PX;
    constexpr uint numTilesZ  = CLUSTER_Z_SLICES;

    uint width  = depth.Width();
    uint height = depth.Height();

    uint numTilesX = (width  + tileSizePx - 1) / tileSizePx;
    uint numTilesY = (height + tileSizePx - 1) / tileSizePx;

    Constants constants{};
    constants.zNear  = camera.GetNearPlane();
    constants.zFar   = camera.GetFarPlane();
    constants.Width  = width;
    constants.Height = height;
    constants.TileSizePixel = tileSizePx;
    constants.InverseProjection = simd::inverse(camera.GetProjectionMatrix());

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Light Cluster Cull");

    // Build clusters
    encoder.PushGroup(@"Build Clusters");
    encoder.SetPipeline(m_ClusterBuild);
    encoder.SetBytes(&constants, sizeof(Constants), 0);
    encoder.SetBuffer(clusterBuffer, 1);
    encoder.Dispatch(
        MTLSizeMake(numTilesX, numTilesY, numTilesZ),
        MTLSizeMake(1, 1, 1)
    );
    encoder.PopGroup();

    // Cull lights
    // TODO

    encoder.End();
}
