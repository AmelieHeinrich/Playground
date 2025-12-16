#include "depth_prepass.h"
#include "metal/command_buffer.h"
#include "metal/graphics_pipeline.h"

#include "metal/indirect_command_buffer.h"
#include "metal/shader.h"
#include "renderer/resource_io.h"
#include "renderer/scene_ab.h"

#include <Metal/MTLIndirectCommandBuffer.h>
#include <Metal/Metal.h>

DepthPrepass::DepthPrepass()
{
    // Pipeline
    GraphicsPipelineDesc desc;
    desc.VertexFunctionName = "prepass_vs";
    desc.FragmentFunctionName = "prepass_fs";
    desc.ColorFormats = {};
    desc.DepthEnabled = true;
    desc.DepthFormat = MTLPixelFormatDepth32Float;
    desc.DepthFunc = MTLCompareFunctionLess;
    desc.SupportsIndirect = YES;

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);
    m_CullPipeline.Initialize("cull_geometry");

    // Textures
    MTLTextureDescriptor* depthDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1 height:1 mipmapped:NO];
    depthDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    depthDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    ResourceIO::CreateTexture(DEPTH_PREPASS_DEPTH_OUTPUT, depthDescriptor);

    // Create ICB
    ResourceIO::CreateIndirectCommandBuffer(DEPTH_PREPASS_ICB, true, MTLIndirectCommandTypeDrawIndexed, MAX_SCENE_INSTANCES);
}

void DepthPrepass::Resize(int width, int height)
{
    ResourceIO::GetTexture(DEPTH_PREPASS_DEPTH_OUTPUT).Resize(width, height);
}

void DepthPrepass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    // Cull
    IndirectCommandBuffer& indirectCommandBuffer = ResourceIO::GetIndirectCommandBuffer(DEPTH_PREPASS_ICB);

    // Reset the indirect command buffer
    BlitEncoder blitEncoder = cmdBuffer.BlitPass(@"Reset Indirect Command Buffer");
    blitEncoder.ResetIndirectCommandBuffer(indirectCommandBuffer, MAX_SCENE_INSTANCES);
    blitEncoder.End();

    // Cull instances
    uint instanceCount = world.GetInstanceCount();
    ComputeEncoder computeEncoder = cmdBuffer.ComputePass(@"Cull Instances");
    computeEncoder.SetPipeline(m_CullPipeline);
    computeEncoder.SetBuffer(world.GetSceneAB(), 0);
    computeEncoder.SetBuffer(indirectCommandBuffer.GetBuffer(), 1);
    computeEncoder.Dispatch(MTLSizeMake(instanceCount, 1, 1), MTLSizeMake(1, 1, 1));
    computeEncoder.End();

    // Optimize indirect command buffer
    blitEncoder = cmdBuffer.BlitPass(@"Optimize Indirect Command Buffer");
    blitEncoder.OptimizeIndirectCommandBuffer(indirectCommandBuffer, MAX_SCENE_INSTANCES);
    blitEncoder.End();

    // Prepass if on macOS
#if !TARGET_OS_IPHONE
    Texture& depthTexture = ResourceIO::GetTexture(DEPTH_PREPASS_DEPTH_OUTPUT);
    Texture& defaultTexture = ResourceIO::GetTexture(DEFAULT_WHITE);

    simd::float4x4 matrix = camera.GetViewProjectionMatrix();

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddDepthStencilTexture(depthTexture)
                                                 .SetName(@"Z-Prepass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBuffer(ShaderStage::VERTEX | ShaderStage::FRAGMENT, world.GetSceneAB(), 0);
    encoder.ExecuteIndirect(indirectCommandBuffer, MAX_SCENE_INSTANCES);
    encoder.End();
#endif
}
