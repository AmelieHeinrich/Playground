#pragma once

#include "renderer/pass.h"
#include "metal/graphics_pipeline.h"

#include "cluster_cull.h"

constexpr const char* FORWARD_PLUS_COLOR_OUTPUT = "ForwardPlus/Color";

class ForwardPlusPass : public Pass
{
public:
    ForwardPlusPass();
    ~ForwardPlusPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
private:
    void ReadbackClusters();

    GraphicsPipeline m_GraphicsPipeline;
    std::vector<Cluster> m_Clusters;
    int m_SelectedZSlice = 0;
    simd::float4x4 m_StoredViewMatrix = matrix_identity_float4x4;
    Camera* m_CurrentCamera = nullptr;
    bool m_ShowHeatmap = false;
    int m_HeatmapMaxLights = 32;
};
