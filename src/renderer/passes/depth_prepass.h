#pragma once

#include "renderer/pass.h"
#include "metal/graphics_pipeline.h"

constexpr const char* DEPTH_PREPASS_DEPTH_OUTPUT = "DepthPrepas/Depth";

class DepthPrepass : public Pass
{
public:
    DepthPrepass();
    ~DepthPrepass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
private:
    GraphicsPipeline m_GraphicsPipeline;
};
