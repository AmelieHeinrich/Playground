#include "depth_prepass.h"
#include "metal/command_buffer.h"
#include "metal/graphics_pipeline.h"

#include "renderer/resource_io.h"

#include <Metal/Metal.h>

DepthPrepass::DepthPrepass()
{
    // Pipeline
    GraphicsPipelineDesc desc;
    desc.Path = "shaders/z_prepass.metal";
    desc.ColorFormats = {};
    desc.DepthEnabled = true;
    desc.DepthFormat = MTLPixelFormatDepth32Float;
    desc.DepthFunc = MTLCompareFunctionLess;

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);

    // Textures
    MTLTextureDescriptor* depthDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1 height:1 mipmapped:NO];
    depthDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    depthDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    ResourceIO::CreateTexture(DEPTH_PREPASS_DEPTH_OUTPUT, depthDescriptor);
}

void DepthPrepass::Resize(int width, int height)
{
    ResourceIO::Get(DEPTH_PREPASS_DEPTH_OUTPUT).Texture.Resize(width, height);
}

void DepthPrepass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
#if !TARGET_OS_IPHONE
    Texture& depthTexture = ResourceIO::Get(DEPTH_PREPASS_DEPTH_OUTPUT).Texture;
    Texture& defaultTexture = ResourceIO::Get(DEFAULT_WHITE).Texture;

    simd::float4x4 matrix = camera.GetViewProjectionMatrix();

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddDepthStencilTexture(depthTexture)
                                                 .SetName(@"Z-Prepass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBytes(ShaderStage::VERTEX, &matrix, sizeof(matrix), 0);
    for (auto& entity : world.GetEntities()) {
        encoder.SetBuffer(ShaderStage::VERTEX, entity.Mesh.VertexBuffer, 1);

        for (auto& mesh : entity.Mesh.Meshes) {
            MeshMaterial& material = entity.Mesh.Materials[mesh.MaterialIndex];
            id<MTLTexture> albedo = (material.AlbedoIndex != -1) ? entity.Mesh.Textures[material.AlbedoIndex].Texture : defaultTexture.GetTexture();

            encoder.SetTexture(ShaderStage::FRAGMENT, albedo, 0);
            encoder.DrawIndexed(MTLPrimitiveTypeTriangle, entity.Mesh.IndexBuffer, mesh.IndexCount, mesh.IndexOffset * sizeof(uint32_t));
        }
    }
    encoder.End();
#endif
}
