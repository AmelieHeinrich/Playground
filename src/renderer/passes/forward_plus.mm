#include "forward_plus.h"
#include "imgui.h"
#include "metal/acceleration_encoder.h"
#include "metal/command_buffer.h"
#include "metal/compute_encoder.h"
#include "metal/graphics_pipeline.h"

#include "metal/indirect_command_buffer.h"
#include "renderer/passes/cluster_cull.h"
#include "renderer/passes/debug_renderer.h"
#include "renderer/resource_io.h"
#include "renderer/scene_ab.h"

#include <Metal/Metal.h>
#include <simd/matrix.h>

struct FPlusGlobalConstants
{
    int TileSizePx;
    int NumTilesX;
    int NumTilesY;
    int NumSlicesZ;

    int Width;
    int Height;
    bool ShowHeatmap;
    bool Pad;
};

ForwardPlusPass::ForwardPlusPass()
{
    // Create pipeline
    GraphicsPipelineDesc desc;
    desc.VertexFunctionName = "fplus_vs";
    desc.FragmentFunctionName = "fplus_fs";
    desc.ColorFormats = {MTLPixelFormatRGBA16Float};
    desc.DepthEnabled = true;
    desc.DepthFormat = MTLPixelFormatDepth32Float;
    desc.DepthFunc = MTLCompareFunctionLess;
    desc.SupportsIndirect = YES;

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);
    m_CullPipeline.Initialize("cull_geometry");

    // Create textures in OBJC++
    MTLTextureDescriptor* colorDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:1 height:1 mipmapped:NO];
    colorDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    colorDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    ResourceIO::CreateTexture(FORWARD_PLUS_COLOR_OUTPUT, colorDescriptor);

    MTLTextureDescriptor* depthDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1 height:1 mipmapped:NO];
    depthDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    depthDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    ResourceIO::CreateTexture(FORWARD_PLUS_DEPTH_OUTPUT, depthDescriptor);

    // Create ICB
    ResourceIO::CreateIndirectCommandBuffer(FORWARD_PLUS_ICB, true, MTLIndirectCommandTypeDrawIndexed, MAX_SCENE_INSTANCES);
}

void ForwardPlusPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(FORWARD_PLUS_COLOR_OUTPUT).Resize(width, height);
    ResourceIO::GetTexture(FORWARD_PLUS_DEPTH_OUTPUT).Resize(width, height);
}

void ForwardPlusPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    // Build TLAS
    AccelerationEncoder accelerationEncoder = cmdBuffer.AccelerationPass(@"Build TLAS");
    accelerationEncoder.BuildTLAS(world.GetTLAS());
    accelerationEncoder.End();

    // Cull instances and build indirect command buffer
    IndirectCommandBuffer& indirectCommandBuffer = ResourceIO::GetIndirectCommandBuffer(FORWARD_PLUS_ICB);

    if (!m_FreezeICB) {
        // Reset the indirect command buffer
        BlitEncoder blitEncoder = cmdBuffer.BlitPass(@"Reset Indirect Command Buffer");
        blitEncoder.ResetIndirectCommandBuffer(indirectCommandBuffer, MAX_SCENE_INSTANCES);
        blitEncoder.End();

        // Cull instances
        Plane frustumPlanes[6];
        camera.ExtractPlanes(frustumPlanes);

        uint instanceCount = world.GetInstanceCount();
        if (instanceCount > 0) {
            ComputeEncoder computeEncoder = cmdBuffer.ComputePass(@"Cull Instances");
            computeEncoder.SetPipeline(m_CullPipeline);
            computeEncoder.SetBuffer(world.GetSceneAB(), 0);
            computeEncoder.SetBuffer(indirectCommandBuffer.GetBuffer(), 1);
            computeEncoder.SetBytes(frustumPlanes, sizeof(frustumPlanes), 2);
            computeEncoder.Dispatch(MTLSizeMake(instanceCount, 1, 1), MTLSizeMake(1, 1, 1));
            computeEncoder.End();

            // Optimize indirect command buffer
            blitEncoder = cmdBuffer.BlitPass(@"Optimize Indirect Command Buffer");
            blitEncoder.OptimizeIndirectCommandBuffer(indirectCommandBuffer, MAX_SCENE_INSTANCES);
            blitEncoder.End();
        }
    }

    // Render pass
    Texture& colorTexture = ResourceIO::GetTexture(FORWARD_PLUS_COLOR_OUTPUT);
    Texture& depthTexture = ResourceIO::GetTexture(FORWARD_PLUS_DEPTH_OUTPUT);
    Texture& defaultTexture = ResourceIO::GetTexture(DEFAULT_WHITE);
    Buffer& lightBins = ResourceIO::GetBuffer(CLUSTER_BINS_BUFFER);
    Buffer& lightBinCounts = ResourceIO::GetBuffer(CLUSTER_BIN_COUNTS_BUFFER);

    int numTilesX = (colorTexture.Width() + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;
    uint numTilesY = (colorTexture.Height() + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;
    uint clusterCount = numTilesX * numTilesY * CLUSTER_Z_SLICES;

    FPlusGlobalConstants globalConstants;
    globalConstants.TileSizePx = CLUSTER_TILE_SIZE_PX;
    globalConstants.NumTilesX = numTilesX;
    globalConstants.NumTilesY = numTilesY;
    globalConstants.NumSlicesZ = CLUSTER_Z_SLICES;
    globalConstants.Width = colorTexture.Width();
    globalConstants.Height = colorTexture.Height();
    globalConstants.ShowHeatmap = m_ShowHeatmap;

    RenderPassInfo info = RenderPassInfo().AddTexture(colorTexture)
                                          .AddDepthStencilTexture(depthTexture)
                                          .SetName(@"Forward+ Pass");
    RenderEncoder encoder = cmdBuffer.RenderPass(info);
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBuffer(ShaderStage::VERTEX, world.GetSceneAB(), 0);
    encoder.SetBytes(ShaderStage::FRAGMENT, &globalConstants, sizeof(globalConstants), 0);
    encoder.SetBuffer(ShaderStage::FRAGMENT, world.GetSceneAB(), 1);
    encoder.SetBuffer(ShaderStage::FRAGMENT, lightBins, 2);
    encoder.SetBuffer(ShaderStage::FRAGMENT, lightBinCounts, 3);
    encoder.ExecuteIndirect(indirectCommandBuffer, MAX_SCENE_INSTANCES);
    encoder.End();
}

void ForwardPlusPass::DebugUI()
{
    if (ImGui::TreeNodeEx("Forward+", ImGuiTreeNodeFlags_Framed)) {
        ImGui::Checkbox("Show Heatmap", &m_ShowHeatmap);
        ImGui::Checkbox("Freeze ICB", &m_FreezeICB);
        ImGui::TreePop();
    }
}
