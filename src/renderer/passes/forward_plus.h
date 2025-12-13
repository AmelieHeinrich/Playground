#pragma once

#include "renderer/pass.h"
#include "metal/graphics_pipeline.h"

constexpr const char* FORWARD_PLUS_COLOR_OUTPUT = "ForwardPlus/Color";
constexpr const char* FORWARD_PLUS_DEPTH_OUTPUT = "ForwardPlus/Depth";

class ForwardPlusPass : public Pass
{
public:
    ForwardPlusPass();
    ~ForwardPlusPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
private:
    GraphicsPipeline m_GraphicsPipeline;
};
