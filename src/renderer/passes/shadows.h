#pragma once

#include "Metal/GraphicsPipeline.h"
#include "Metal/IndirectCommandBuffer.h"
#include "Renderer/Pass.h"

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
    LOW = 0,
    MEDIUM = 1,
    HIGH = 2,
    ULTRA = 3
};

// Helper function to convert enum to cascade size
inline int ShadowResolutionToSize(ShadowResolution resolution)
{
    switch (resolution)
    {
        case ShadowResolution::LOW:    return 512;
        case ShadowResolution::MEDIUM: return 1024;
        case ShadowResolution::HIGH:   return 2048;
        case ShadowResolution::ULTRA:  return 4096;
        default:                       return 2048;
    }
}

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
    void RegisterCVars() override;

    // Accessors for SwiftUI bridge
    ShadowTechnique GetTechnique() const { return m_Technique; }
    void SetTechnique(ShadowTechnique t) { m_Technique = t; }
    
    ShadowResolution GetResolution() const { return m_Resolution; }
    void SetResolution(ShadowResolution r) { m_Resolution = r; }
    
    float GetSplitLambda() const { return m_SplitLambda; }
    void SetSplitLambda(float l) { m_SplitLambda = l; }
    
    bool GetUpdateCascades() const { return m_UpdateCascades; }
    void SetUpdateCascades(bool u) { m_UpdateCascades = u; }

private:
    void None(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void RaytracedHard(CommandBuffer& cmdBuffer, World& world, Camera& camera);

    void CSM(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void UpdateCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void CullCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void DrawCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void PopulateCSMVisibility(CommandBuffer& cmdBuffer, World& world, Camera& camera);

    ShadowTechnique m_Technique = ShadowTechnique::CSM;

    // Hard RT Kernel
    ComputePipeline m_HardRTKernel;

    // CSM
    ShadowResolution m_Resolution = ShadowResolution::HIGH;
    Texture m_ShadowCascades[SHADOW_CASCADE_COUNT];
    IndirectCommandBuffer m_CascadeICBs[SHADOW_CASCADE_COUNT];
    ShadowCascade m_Cascades[SHADOW_CASCADE_COUNT];
    float m_SplitLambda = 0.95f;
    bool m_UpdateCascades = true;

    ComputePipeline m_CullCascadesKernel;
    GraphicsPipeline m_DrawCascadesPipeline;
    ComputePipeline m_FillCascadesKernel;
};
