#pragma once

#include "Renderer/Pass.h"

class SkyDrawPass : public Pass
{
public:
    SkyDrawPass();
    ~SkyDrawPass() = default;

    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
private:
    GraphicsPipeline m_GraphicsPipeline;
};
