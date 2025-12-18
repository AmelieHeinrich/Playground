#pragma once

#include "renderer/pass.h"

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
private:
    GraphicsPipeline m_Pipeline;

    bool m_FreezeICB = false;
};
