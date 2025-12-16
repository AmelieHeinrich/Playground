#include "forward_plus.h"
#include "imgui.h"
#include "metal/compute_encoder.h"
#include "metal/graphics_pipeline.h"

#include "renderer/passes/cluster_cull.h"
#include "renderer/passes/debug_renderer.h"
#include "renderer/passes/depth_prepass.h"
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
#if TARGET_OS_IPHONE
    desc.DepthFunc = MTLCompareFunctionLess;
#else
    desc.DepthFunc = MTLCompareFunctionEqual;
#endif
    desc.SupportsIndirect = YES;

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);
    m_CullInstancePipeline.Initialize("cull_geometry");

    // Initialize ICB
    m_IndirectCommandBuffer.Initialize(false, MTLIndirectCommandTypeDrawIndexed, MAX_SCENE_INSTANCES);

    // Create textures in OBJC++
    MTLTextureDescriptor* colorDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:1 height:1 mipmapped:NO];
    colorDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    colorDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    ResourceIO::CreateTexture(FORWARD_PLUS_COLOR_OUTPUT, colorDescriptor);
}

void ForwardPlusPass::Resize(int width, int height)
{
    ResourceIO::Get(FORWARD_PLUS_COLOR_OUTPUT).Texture.Resize(width, height);
}

void ForwardPlusPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& colorTexture = ResourceIO::Get(FORWARD_PLUS_COLOR_OUTPUT).Texture;
    Texture& depthTexture = ResourceIO::Get(DEPTH_PREPASS_DEPTH_OUTPUT).Texture;
    Texture& defaultTexture = ResourceIO::Get(DEFAULT_WHITE).Texture;
    Buffer& lightBins = ResourceIO::Get(CLUSTER_BINS_BUFFER).Buffer;
    Buffer& lightBinCounts = ResourceIO::Get(CLUSTER_BIN_COUNTS_BUFFER).Buffer;

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

    // Reset the indirect command buffer
    BlitEncoder blitEncoder = cmdBuffer.BlitPass(@"Reset Indirect Command Buffer");
    blitEncoder.ResetIndirectCommandBuffer(m_IndirectCommandBuffer, MAX_SCENE_INSTANCES);
    blitEncoder.End();

    // Cull instances
    uint instanceCount = world.GetInstanceCount();
    ComputeEncoder computeEncoder = cmdBuffer.ComputePass(@"Cull Instances");
    computeEncoder.SetPipeline(m_CullInstancePipeline);
    computeEncoder.SetBuffer(world.GetSceneAB(), 0);
    computeEncoder.SetBuffer(m_IndirectCommandBuffer.GetBuffer(), 1);
    computeEncoder.Dispatch(MTLSizeMake(instanceCount, 1, 1), MTLSizeMake(1, 1, 1));
    computeEncoder.End();

    // Optimize indirect command buffer
    blitEncoder = cmdBuffer.BlitPass(@"Optimize Indirect Command Buffer");
    blitEncoder.OptimizeIndirectCommandBuffer(m_IndirectCommandBuffer, instanceCount);
    blitEncoder.End();

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(colorTexture)
#if TARGET_OS_IPHONE
                                                 .AddDepthStencilTexture(depthTexture)
#else
                                                 .AddDepthStencilTexture(depthTexture, false)
#endif
                                                 .SetName(@"Forward+ Pass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBuffer(ShaderStage::VERTEX, world.GetSceneAB(), 0);
    encoder.SetBytes(ShaderStage::FRAGMENT, &globalConstants, sizeof(globalConstants), 0);
    encoder.SetBuffer(ShaderStage::FRAGMENT, world.GetSceneAB(), 1);
    encoder.SetBuffer(ShaderStage::FRAGMENT, lightBins, 2);
    encoder.SetBuffer(ShaderStage::FRAGMENT, lightBinCounts, 3);
    encoder.ExecuteIndirect(m_IndirectCommandBuffer, MAX_SCENE_INSTANCES);
    encoder.End();
}

void ForwardPlusPass::DebugUI()
{
    if (ImGui::TreeNodeEx("Forward+", ImGuiTreeNodeFlags_Framed)) {
        ImGui::Checkbox("Show Heatmap", &m_ShowHeatmap);
        ImGui::TreePop();
    }
}
