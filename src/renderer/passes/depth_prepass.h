#pragma once

#include "metal/compute_pipeline.h"
#include "renderer/pass.h"
#include "metal/graphics_pipeline.h"

constexpr const char* DEPTH_PREPASS_DEPTH_OUTPUT = "DepthPrepas/Depth";
constexpr const char* DEPTH_PREPASS_ICB = "DepthPrepas/IndirectCommandBuffer";

class DepthPrepass : public Pass
{
public:
    DepthPrepass();
    ~DepthPrepass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
private:
    ComputePipeline m_CullPipeline;
    GraphicsPipeline m_GraphicsPipeline;
};
