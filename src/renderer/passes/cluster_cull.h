#pragma once

#include "metal/compute_pipeline.h"
#include "renderer/pass.h"

constexpr const char* CLUSTER_BUFFER = "ClusterCull/Clusters";
constexpr const char* CLUSTER_BINS_BUFFER = "ClusterCull/Bins";
constexpr const char* CLUSTER_BIN_COUNTS_BUFFER = "ClusterCull/BinCounts";
constexpr const char* VISIBLE_LIGHTS_BUFFER = "ClusterCull/VisibleLights";
constexpr const char* VISIBLE_LIGHTS_COUNT_BUFFER = "ClusterCull/VisibleLightsCount";

#if TARGET_PLATFORM_IOS
constexpr int CLUSTER_TILE_SIZE_PX = 32;
constexpr int CLUSTER_Z_SLICES = 18;
constexpr int CLUSTER_MAX_LIGHTS = 256;
#else
constexpr int CLUSTER_TILE_SIZE_PX = 32;
constexpr int CLUSTER_Z_SLICES = 24;
constexpr int CLUSTER_MAX_LIGHTS = 256;
#endif

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
    ComputePipeline m_FrustumLightCull;
    ComputePipeline m_ClusterBuild;
    ComputePipeline m_ClusterCull;
};
