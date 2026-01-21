#include "Tonemap.h"
#include "Metal/CommandBuffer.h"
#include "Metal/GraphicsPipeline.h"
#include "Renderer/ResourceIo.h"
#include "Swift/CVarRegistry.h"

#include <Metal/Metal.h>


TonemapPass::TonemapPass()
{
    // Graphics pipeline
    GraphicsPipelineDesc pipelineDesc;
    pipelineDesc.ColorFormats = { MTLPixelFormatBGRA8Unorm };
    pipelineDesc.VertexFunctionName = "blit_vs";
    pipelineDesc.FragmentFunctionName = "blit_fs";

    m_BlitPipeline = GraphicsPipeline::Create(pipelineDesc);

    // Compute pipeline
    m_Pipeline.Initialize("tonemap_cs");

    // Textures
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    descriptor.storageMode = MTLStorageModePrivate;

    ResourceIO::CreateTexture("Tonemap/Output", descriptor);
}

void TonemapPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(TONEMAP_OUTPUT).Resize(width, height);
}

void TonemapPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& output = ResourceIO::GetTexture(TONEMAP_OUTPUT);
    Texture& input = ResourceIO::GetTexture(TONEMAP_INPUT_COLOR);

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Tonemap");
    encoder.SetPipeline(m_Pipeline);
    encoder.SetTexture(input, 0);
    encoder.SetTexture(output, 1);
    encoder.SetBytes(&m_Gamma, sizeof(float), 2);
    encoder.Dispatch(
        MTLSizeMake((output.Width() + 7) / 8, (output.Height() + 7) / 8, 1),
        MTLSizeMake(8, 8, 1)
    );
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
    // UI is now handled by SwiftUI
}

void TonemapPass::RegisterCVars()
{
    CVarRegistry* registry = [CVarRegistry shared];
    [registry registerFloat:@"Tonemap.Gamma"
                    pointer:&m_Gamma
                        min:1.0f
                        max:3.0f
                displayName:@"Gamma Correction"];
}
