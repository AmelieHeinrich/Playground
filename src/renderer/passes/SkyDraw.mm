#include "SkyDraw.h"
#include "Deferred.h"
#include "GBuffer.h"
#include "Renderer/ResourceIo.h"
#include <Metal/Metal.h>

SkyDrawPass::SkyDrawPass()
{
    GraphicsPipelineDesc pipelineDesc;
    pipelineDesc.ColorFormats = { MTLPixelFormatRGBA16Float };
    pipelineDesc.DepthEnabled = YES;
    pipelineDesc.DepthFormat = MTLPixelFormatDepth32Float;
    pipelineDesc.DepthFunc = MTLCompareFunctionLessEqual;
    pipelineDesc.DepthWriteEnabled = NO;
    pipelineDesc.SupportsIndirect = NO;
    pipelineDesc.VertexFunctionName = "draw_sky_scene_vs";
    pipelineDesc.FragmentFunctionName = "draw_sky_fs";

    m_GraphicsPipeline = GraphicsPipeline::Create(pipelineDesc);
}

void SkyDrawPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);
    Texture& color = ResourceIO::GetTexture(DEFERRED_COLOR);

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo().AddTexture(color, false)
        .AddDepthStencilTexture(depth, false)
        .SetName(@"Skybox Pass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBytes(ShaderStage::VERTEX, camera.GetViewProjectionMatrix().columns, sizeof(simd::float4x4), 0);
    encoder.SetTexture(ShaderStage::FRAGMENT, world.GetSkybox(), 0);
    encoder.Draw(MTLPrimitiveTypeTriangle, 36, 0);
    encoder.End();
}
