#pragma once

#include "metal/graphics_pipeline.h"
#include "metal/indirect_command_buffer.h"
#include "renderer/pass.h"

constexpr const char* SHADOW_VISIBILITY_OUTPUT = "Shadow/Visibility";

constexpr const int SHADOW_CASCADE_COUNT = 4;

enum class ShadowTechnique
{
    NONE,
    RAYTRACED_HARD,
    CSM,
    // TODO: Raytraced soft
};

enum class ShadowResolution
{
    LOW = 512,
    MEDIUM = 1024,
    HIGH = 2048,
    ULTRA = 4096
};

struct ShadowCascade
{
    float Split;
    uint64_t CascadeID;
    simd::float4x4 View;
    simd::float4x4 Projection;
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

    void CSM(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void UpdateCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void CullCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void DrawCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void PopulateCSMVisibility(CommandBuffer& cmdBuffer, World& world, Camera& camera);

    ShadowTechnique m_Technique = ShadowTechnique::NONE;

    // Hard RT Kernel
    ComputePipeline m_HardRTKernel;

    // CSM
    ShadowResolution m_Resolution = ShadowResolution::HIGH;
    std::shared_ptr<Texture> m_ShadowCascades[SHADOW_CASCADE_COUNT];
    std::shared_ptr<IndirectCommandBuffer> m_CascadeICBs[SHADOW_CASCADE_COUNT];
    ShadowCascade m_Cascades[SHADOW_CASCADE_COUNT];
    float m_SplitLambda = 0.95f;

    ComputePipeline m_CullCascadesKernel;
    GraphicsPipeline m_DrawCascadesKernel;
    ComputePipeline m_FillCascadesKernel;
};
