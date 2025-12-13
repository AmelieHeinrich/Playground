#include "forward_plus.h"
#include "metal/graphics_pipeline.h"

#include "renderer/resource_io.h"

#include <Metal/Metal.h>

ForwardPlusPass::ForwardPlusPass()
{
    // Create pipeline
    GraphicsPipelineDesc desc;
    desc.Path = "shaders/model.metal";
    desc.ColorFormats = {MTLPixelFormatRGBA16Float};
    desc.DepthEnabled = true;
    desc.DepthFormat = MTLPixelFormatDepth32Float;
    desc.DepthFunc = MTLCompareFunctionLess;

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);

    // Create textures in OBJC++
    MTLTextureDescriptor* colorDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:1 height:1 mipmapped:NO];
    colorDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    colorDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    MTLTextureDescriptor* depthDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1 height:1 mipmapped:NO];
    depthDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    depthDescriptor.resourceOptions = MTLResourceStorageModePrivate;

    ResourceIO::CreateTexture(FORWARD_PLUS_COLOR_OUTPUT, colorDescriptor);
    ResourceIO::CreateTexture(FORWARD_PLUS_DEPTH_OUTPUT, depthDescriptor);
}

void ForwardPlusPass::Resize(int width, int height)
{
    ResourceIO::Get(FORWARD_PLUS_COLOR_OUTPUT).Texture.Resize(width, height);
    ResourceIO::Get(FORWARD_PLUS_DEPTH_OUTPUT).Texture.Resize(width, height);
}

void ForwardPlusPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& colorTexture = ResourceIO::Get(FORWARD_PLUS_COLOR_OUTPUT).Texture;
    Texture& depthTexture = ResourceIO::Get(FORWARD_PLUS_DEPTH_OUTPUT).Texture;

    simd_float4x4 matrix = camera.GetViewProjectionMatrix();

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(colorTexture)
                                                 .AddDepthStencilTexture(depthTexture)
                                                 .SetName(@"Forward Pass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBytes(ShaderStage::VERTEX, &matrix, sizeof(matrix), 0);
    for (auto& entity : world.GetEntities()) {
        // Set shared buffers for the entire model
        encoder.SetBuffer(ShaderStage::VERTEX, entity.Mesh.VertexBuffer, 1);
        
        for (auto& mesh : entity.Mesh.Meshes) {
            id<MTLTexture> albedo = entity.Mesh.Textures[entity.Mesh.Materials[mesh.MaterialIndex].AlbedoIndex].Texture;

            encoder.SetTexture(ShaderStage::FRAGMENT, albedo, 0);
            encoder.DrawIndexed(MTLPrimitiveTypeTriangle, entity.Mesh.IndexBuffer, mesh.IndexCount, mesh.IndexOffset * sizeof(uint32_t));
        }
    }
    encoder.End();
}
