#pragma once

#include "metal/compute_pipeline.h"
#include "metal/graphics_pipeline.h"
#include "renderer/pass.h"

#include "deferred.h"

constexpr const char* TONEMAP_INPUT_COLOR = DEFERRED_COLOR;
constexpr const char* TONEMAP_OUTPUT = "Tonemap/Output";

class TonemapPass : public Pass
{
public:
    TonemapPass();
    ~TonemapPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;

private:
    ComputePipeline m_Pipeline;
    GraphicsPipeline m_BlitPipeline;

    float m_Gamma = 2.2f;
};
