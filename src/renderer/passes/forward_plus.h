#pragma once

#include "metal/compute_pipeline.h"
#include "metal/indirect_command_buffer.h"
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
    IndirectCommandBuffer m_IndirectCommandBuffer;
    ComputePipeline m_CullInstancePipeline;
    GraphicsPipeline m_GraphicsPipeline;

    bool m_ShowHeatmap = false;
};
