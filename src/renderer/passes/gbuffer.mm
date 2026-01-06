#include "gbuffer.h"
#include "renderer/resource_io.h"

#include <imgui.h>

GBufferPass::GBufferPass()
{
    // Pipeline
    GraphicsPipelineDesc pipelineDesc;
    pipelineDesc.ColorFormats = { MTLPixelFormatRGBA8Unorm, MTLPixelFormatRGBA16Float, MTLPixelFormatRG8Unorm };
    pipelineDesc.DepthEnabled = YES;
    pipelineDesc.DepthFormat = MTLPixelFormatDepth32Float;
    pipelineDesc.DepthFunc = MTLCompareFunctionLess;
    pipelineDesc.DepthWriteEnabled = YES;
    pipelineDesc.SupportsIndirect = YES;
    pipelineDesc.VertexFunctionName = "gbuffer_vs";
    pipelineDesc.FragmentFunctionName = "gbuffer_fs";

    m_Pipeline = GraphicsPipeline::Create(pipelineDesc);
    m_CullPipeline.Initialize("cull_geometry");

    // Textures
    MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:false];
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;

    ResourceIO::CreateTexture(GBUFFER_ALBEDO_OUTPUT, textureDescriptor);
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA16Float;
    ResourceIO::CreateTexture(GBUFFER_NORMAL_OUTPUT, textureDescriptor);
    textureDescriptor.pixelFormat = MTLPixelFormatRG8Unorm;
    ResourceIO::CreateTexture(GBUFFER_PBR_OUTPUT, textureDescriptor);
    textureDescriptor.pixelFormat = MTLPixelFormatDepth32Float;
    ResourceIO::CreateTexture(GBUFFER_DEPTH_OUTPUT, textureDescriptor);

    // ICB
    ResourceIO::CreateIndirectCommandBuffer(GBUFFER_ICB, YES, MTLIndirectCommandTypeDrawIndexed, MAX_SCENE_INSTANCES);
}

void GBufferPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(GBUFFER_ALBEDO_OUTPUT).Resize(width, height);
    ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT).Resize(width, height);
    ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT).Resize(width, height);
    ResourceIO::GetTexture(GBUFFER_PBR_OUTPUT).Resize(width, height);
}

void GBufferPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    BuildAccelerationStructure(cmdBuffer, world, camera);
    if (!m_FreezeICB) CullInstances(cmdBuffer, world, camera);
    RenderGBuffer(cmdBuffer, world, camera);
}

void GBufferPass::BuildAccelerationStructure(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    AccelerationEncoder accelerationEncoder = cmdBuffer.AccelerationPass(@"Build TLAS");
    accelerationEncoder.BuildTLAS(world.GetTLAS());
    accelerationEncoder.End();
}

void GBufferPass::CullInstances(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    IndirectCommandBuffer& icb = ResourceIO::GetIndirectCommandBuffer(GBUFFER_ICB);

    BlitEncoder blitEncoder = cmdBuffer.BlitPass(@"Reset Indirect Command Buffer");
    blitEncoder.ResetIndirectCommandBuffer(icb, MAX_SCENE_INSTANCES);
    blitEncoder.End();

    Plane frustumPlanes[6];
    extract_frustum_planes(camera.GetViewProjectionMatrix(), frustumPlanes);

    uint instanceCount = world.GetInstanceCount();
    if (instanceCount > 0) {
        ComputeEncoder computeEncoder = cmdBuffer.ComputePass(@"Cull Instances");
        computeEncoder.SetPipeline(m_CullPipeline);
        computeEncoder.SetBuffer(world.GetSceneAB(), 0);
        computeEncoder.SetBuffer(icb.GetBuffer(), 1);
        computeEncoder.SetBytes(frustumPlanes, sizeof(frustumPlanes), 2);
        computeEncoder.SetBytes(&instanceCount, sizeof(uint), 3);
        computeEncoder.Dispatch(MTLSizeMake(instanceCount, 1, 1), MTLSizeMake(1, 1, 1));
        computeEncoder.End();

        // Optimize indirect command buffer
        blitEncoder = cmdBuffer.BlitPass(@"Optimize Indirect Command Buffer");
        blitEncoder.OptimizeIndirectCommandBuffer(icb, MAX_SCENE_INSTANCES);
        blitEncoder.End();
    }
}

void GBufferPass::RenderGBuffer(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);
    Texture& albedo = ResourceIO::GetTexture(GBUFFER_ALBEDO_OUTPUT);
    Texture& normal = ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT);
    Texture& pbr = ResourceIO::GetTexture(GBUFFER_PBR_OUTPUT);
    IndirectCommandBuffer& icb = ResourceIO::GetIndirectCommandBuffer(GBUFFER_ICB);

    RenderPassInfo info = RenderPassInfo().AddTexture(albedo)
                                          .AddTexture(normal)
                                          .AddTexture(pbr)
                                          .AddDepthStencilTexture(depth)
                                          .SetName(@"GBuffer Pass");
    RenderEncoder encoder = cmdBuffer.RenderPass(info);
    encoder.SetGraphicsPipeline(m_Pipeline);
    encoder.SetBuffer(ShaderStage::VERTEX | ShaderStage::FRAGMENT, world.GetSceneAB(), 0);
    encoder.ExecuteIndirect(icb, MAX_SCENE_INSTANCES);
    encoder.End();
}

void GBufferPass::DebugUI()
{
    if (ImGui::TreeNodeEx("GBuffer", ImGuiTreeNodeFlags_Framed)) {
        ImGui::Checkbox("Freeze ICB", &m_FreezeICB);
        ImGui::TreePop();
    }
}
