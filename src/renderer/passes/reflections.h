#pragma once

#include "metal/compute_encoder.h"
#include "metal/compute_pipeline.h"
#include "renderer/pass.h"

enum class ReflectionTechnique
{
    NONE,
    SCREEN_SPACE_MIRROR,
    HYBRID_MIRROR,
    SCREEN_SPACE_GLOSSY,
    HYBRID_GLOSSY
};

class ReflectionPass : public Pass
{
public:
    ReflectionPass();
    ~ReflectionPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
private:
    void None(CommandBuffer& cmdBuffer, World& world, Camera& camera) {}
    void ScreenSpaceMirror(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void HybridMirror(CommandBuffer& cmdBuffer, World& world, Camera& camera) {}
    void ScreenSpaceGlossy(CommandBuffer& cmdBuffer, World& world, Camera& camera) {}
    void HybridGlossy(CommandBuffer& cmdBuffer, World& world, Camera& camera) {}

    ReflectionTechnique m_Technique = ReflectionTechnique::SCREEN_SPACE_MIRROR;

    Texture m_OutputTexture;
    ComputePipeline m_SSMirrorKernel;
};
