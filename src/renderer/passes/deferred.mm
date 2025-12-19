#include "deferred.h"
#include "cluster_cull.h"
#include "gbuffer.h"

#include "renderer/resource_io.h"

#include <imgui.h>

struct DeferredConstants
{
    uint TileSizePx;
    uint NumTilesX;
    uint NumTilesY;
    uint NumSlicesZ;

    uint ScreenWidth;
    uint ScreenHeight;
    bool ShowHeatmap;
    bool Pad;
};

DeferredPass::DeferredPass()
{
    // Pipeline
    m_Pipeline.Initialize("deferred_cs");

    // Texture
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

    ResourceIO::CreateTexture(DEFERRED_COLOR, descriptor);
}

void DeferredPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(DEFERRED_COLOR).Resize(width, height);
}

void DeferredPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);
    Texture& albedo = ResourceIO::GetTexture(GBUFFER_ALBEDO_OUTPUT);
    Texture& normal = ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT);
    Texture& pbr = ResourceIO::GetTexture(GBUFFER_PBR_OUTPUT);
    Texture& color = ResourceIO::GetTexture(DEFERRED_COLOR);
    Buffer& lightBins = ResourceIO::GetBuffer(CLUSTER_BINS_BUFFER);
    Buffer& lightBinCounts = ResourceIO::GetBuffer(CLUSTER_BIN_COUNTS_BUFFER);

    uint numTilesX = (color.Width() + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;
    uint numTilesY = (color.Height() + CLUSTER_TILE_SIZE_PX - 1) / CLUSTER_TILE_SIZE_PX;
    uint clusterCount = numTilesX * numTilesY * CLUSTER_Z_SLICES;

    DeferredConstants constants = {
        .TileSizePx = CLUSTER_TILE_SIZE_PX,
        .NumTilesX = numTilesX,
        .NumTilesY = numTilesY,
        .NumSlicesZ = CLUSTER_Z_SLICES,
        .ScreenWidth = color.Width(),
        .ScreenHeight = color.Height(),
        .ShowHeatmap = m_ShowHeatmap
    };

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Deferred Pass");
    encoder.SetPipeline(m_Pipeline);
    encoder.SetTexture(depth, 0);
    encoder.SetTexture(albedo, 1);
    encoder.SetTexture(normal, 2);
    encoder.SetTexture(pbr, 3);
    encoder.SetTexture(color, 4);
    encoder.SetBuffer(world.GetSceneAB(), 0);
    encoder.SetBytes(&constants, sizeof(constants), 1);
    encoder.SetBuffer(lightBins, 2);
    encoder.SetBuffer(lightBinCounts, 3);
    encoder.Dispatch(
        MTLSizeMake((color.Width() + 8) / 7, (color.Height() + 8) / 7, 1),
        MTLSizeMake(8, 8, 1)
    );
    encoder.End();
}

void DeferredPass::DebugUI()
{
    if (ImGui::TreeNodeEx("Deferred", ImGuiTreeNodeFlags_Framed)) {
        ImGui::Checkbox("Show Cluster Heatmap", &m_ShowHeatmap);
        ImGui::TreePop();
    }
}
