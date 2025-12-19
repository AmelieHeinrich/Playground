#pragma once

#include "renderer/pass.h"

constexpr const char* DEFERRED_COLOR = "Deferred/Color";

class DeferredPass : public Pass
{
public:
    DeferredPass();
    ~DeferredPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
private:
    ComputePipeline m_Pipeline;

    bool m_ShowHeatmap = false;
};
