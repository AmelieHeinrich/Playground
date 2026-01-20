#pragma once

#include "Renderer/Pass.h"

constexpr const char* DEFERRED_COLOR = "Deferred/Color";

class DeferredPass : public Pass
{
public:
    DeferredPass();
    ~DeferredPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
    void RegisterCVars() override;

    // Accessors for SwiftUI bridge
    bool GetShowHeatmap() const { return m_ShowHeatmap; }
    void SetShowHeatmap(bool show) { m_ShowHeatmap = show; }

private:
    ComputePipeline m_Pipeline;

    bool m_ShowHeatmap = false;
};
