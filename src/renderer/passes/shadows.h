#pragma once

#include "renderer/pass.h"

constexpr const char* SHADOW_VISIBILITY_OUTPUT = "Shadow/Visibility";

enum class ShadowTechnique
{
    NONE,
    RAYTRACED_HARD,
    // TODO: Raytraced soft
    // TODO: Cascaded Shadow Maps
};

class ShadowPass : public Pass
{
public:
    ShadowPass();
    ~ShadowPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
private:
    void None(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void RaytracedHard(CommandBuffer& cmdBuffer, World& world, Camera& camera);

    ComputePipeline m_Pipeline;
    ShadowTechnique m_Technique = ShadowTechnique::RAYTRACED_HARD;
};
