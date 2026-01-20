#pragma once

#include "Renderer/Pass.h"

constexpr const char* GBUFFER_DEPTH_OUTPUT = "GBuffer/Depth";
constexpr const char* GBUFFER_NORMAL_OUTPUT = "GBuffer/Normal";
constexpr const char* GBUFFER_ALBEDO_OUTPUT = "GBuffer/Albedo";
constexpr const char* GBUFFER_PBR_OUTPUT = "GBuffer/PBR";
constexpr const char* GBUFFER_ICB = "GBuffer/IndirectCommandBuffer";

class GBufferPass : public Pass
{
public:
    GBufferPass();
    ~GBufferPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
    void RegisterCVars() override;

    // Accessors for SwiftUI bridge
    bool GetFreezeICB() const { return m_FreezeICB; }
    void SetFreezeICB(bool freeze) { m_FreezeICB = freeze; }

private:
    void BuildAccelerationStructure(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void CullInstances(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void RenderGBuffer(CommandBuffer& cmdBuffer, World& world, Camera& camera);

private:
    ComputePipeline m_CullPipeline;
    GraphicsPipeline m_Pipeline;

    bool m_FreezeICB = false;
};
