#pragma once

#include "metal/compute_pipeline.h"
#include "renderer/pass.h"

constexpr const char* CLUSTER_BUFFER = "ClusterCull/Clusters";
constexpr int CLUSTER_TILE_SIZE_PX = 16;
constexpr int CLUSTER_Z_SLICES = 24;

struct Cluster
{
    simd::float4 Min;
    simd::float4 Max;
};

class ClusterCullPass : public Pass
{
public:
    ClusterCullPass();
    ~ClusterCullPass() = default;

    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
private:
    ComputePipeline m_ClusterBuild;
};
