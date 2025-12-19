#include "shadows.h"
#include "gbuffer.h"
#include "renderer/resource_io.h"

#include <Metal/Metal.h>
#include <imgui.h>

ShadowPass::ShadowPass()
{
    // Pipeline
    m_Pipeline.Initialize("rt_shadows_cs");

    // Texture
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

    ResourceIO::CreateTexture(SHADOW_VISIBILITY_OUTPUT, descriptor);
}

void ShadowPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT).Resize(width, height);
}

void ShadowPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    switch (m_Technique) {
        case ShadowTechnique::NONE:
            None(cmdBuffer, world, camera);
            break;
        case ShadowTechnique::RAYTRACED_HARD:
            RaytracedHard(cmdBuffer, world, camera);
            break;
    }
}

void ShadowPass::DebugUI()
{
    if (ImGui::TreeNodeEx("Shadows", ImGuiTreeNodeFlags_Framed)) {
        const char* techniques[] = {"None", "Raytraced Hard"};
        int selected = static_cast<int>(m_Technique);
        ImGui::Combo("Technique", &selected, techniques, IM_ARRAYSIZE(techniques));
        m_Technique = static_cast<ShadowTechnique>(selected);

        ImGui::TreePop();
    }
}

void ShadowPass::None(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& visibility = ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT);

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(visibility, true, simd::make_float4(1.0f, 1.0f, 1.0f, 1.0f))
                                                 .SetName(@"Shadow Pass (None)"));
    encoder.End();
}

void ShadowPass::RaytracedHard(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& visibility = ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT);
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);
    Texture& normal = ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT);

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Shadow Pass (Raytraced Hard)");
    encoder.SetPipeline(m_Pipeline);
    encoder.SetTexture(visibility, 0);
    encoder.SetTexture(depth, 1);
    encoder.SetTexture(normal, 2);
    encoder.SetBuffer(world.GetSceneAB(), 0);
    encoder.Dispatch(
        MTLSizeMake((visibility.Width() + 7) / 8, (visibility.Height() + 7) / 8, 1),
        MTLSizeMake(8, 8, 1)
    );
    encoder.End();
}
