#include "tonemap.h"
#include "metal/command_buffer.h"
#include "metal/graphics_pipeline.h"
#include "renderer/resource_io.h"

#include <Metal/Metal.h>
#include <imgui.h>

TonemapPass::TonemapPass()
{
    // Graphics pipeline
    GraphicsPipelineDesc pipelineDesc;
    pipelineDesc.ColorFormats = { MTLPixelFormatBGRA8Unorm };
    pipelineDesc.Path = "shaders/blit.metal";

    m_BlitPipeline = GraphicsPipeline::Create(pipelineDesc);

    // Compute pipeline
    m_Pipeline.Initialize("shaders/tonemap.metal");

    // Textures
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    descriptor.storageMode = MTLStorageModePrivate;

    ResourceIO::CreateTexture("Tonemap/Output", descriptor);
}

void TonemapPass::Resize(int width, int height)
{
    Resource& texture = ResourceIO::Get(TONEMAP_OUTPUT);
    texture.Texture.Resize(width, height);
}

void TonemapPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& output = ResourceIO::Get(TONEMAP_OUTPUT).Texture;
    Texture& input = ResourceIO::Get(TONEMAP_INPUT_COLOR).Texture;

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Tonemap");
    encoder.SetPipeline(m_Pipeline);
    encoder.SetTexture(input, 0);
    encoder.SetTexture(output, 1);
    encoder.SetBytes(&m_Gamma, sizeof(float), 2);
    encoder.Dispatch(MTLSizeMake(output.Width() / 8, output.Height() / 8, 1), MTLSizeMake(8, 8, 1));
    encoder.End();

    // Copy to drawable
    RenderEncoder renderEncoder = cmdBuffer.RenderPass(RenderPassInfo().AddTexture(cmdBuffer.GetDrawable()).SetName(@"Blit to Drawable"));
    renderEncoder.SetGraphicsPipeline(m_BlitPipeline);
    renderEncoder.SetTexture(ShaderStage::FRAGMENT, output, 0);
    renderEncoder.Draw(MTLPrimitiveTypeTriangle, 3, 0);
    renderEncoder.End();
}

void TonemapPass::DebugUI()
{
    if (ImGui::TreeNodeEx("Tonemap + Gamma", ImGuiTreeNodeFlags_Framed)) {
        ImGui::SliderFloat("Gamma", &m_Gamma, 0.1f, 5.0f);
        ImGui::TreePop();
    }
}
