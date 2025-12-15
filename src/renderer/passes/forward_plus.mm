#include "forward_plus.h"
#include "metal/graphics_pipeline.h"

#include "renderer/passes/depth_prepass.h"
#include "renderer/resource_io.h"

#include <Metal/Metal.h>

struct MaterialConstants
{
    bool hasAlbedo;
    bool hasNormal;
    bool hasORM;
    bool pad;
};

struct FPlusGlobalConstants
{
    simd::float4x4 CameraMatrix;
    simd::float3 CameraPosition;
    int PointLightCount;
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

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);

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

    FPlusGlobalConstants globalConstants;
    globalConstants.CameraMatrix = camera.GetViewProjectionMatrix();
    globalConstants.CameraPosition = camera.GetPosition();
    globalConstants.PointLightCount = world.GetLightList().GetPointLightCount();

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(colorTexture)
#if TARGET_OS_IPHONE
                                                 .AddDepthStencilTexture(depthTexture)
#else
                                                 .AddDepthStencilTexture(depthTexture, false)
#endif
                                                 .SetName(@"Forward Pass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBytes(ShaderStage::VERTEX | ShaderStage::FRAGMENT, &globalConstants, sizeof(globalConstants), 0);
    encoder.SetBuffer(ShaderStage::FRAGMENT, world.GetLightList().GetPointLightBuffer(), 2);
    for (auto& entity : world.GetEntities()) {
        encoder.SetBuffer(ShaderStage::VERTEX, entity.Mesh.VertexBuffer, 1);

        for (auto& mesh : entity.Mesh.Meshes) {
            MeshMaterial& material = entity.Mesh.Materials[mesh.MaterialIndex];

            MaterialConstants constants;
            constants.hasAlbedo = material.AlbedoIndex != -1;
            constants.hasNormal = material.NormalIndex != -1;
            constants.hasORM = material.PBRIndex != -1;

            id<MTLTexture> albedo = constants.hasAlbedo ? entity.Mesh.Textures[material.AlbedoIndex].Texture : defaultTexture.GetTexture();
            id<MTLTexture> normal = constants.hasNormal ? entity.Mesh.Textures[material.NormalIndex].Texture : defaultTexture.GetTexture();
            id<MTLTexture> orm = constants.hasORM ? entity.Mesh.Textures[material.PBRIndex].Texture : defaultTexture.GetTexture();

            encoder.SetBytes(ShaderStage::FRAGMENT, &constants, sizeof(constants), 1);
            encoder.SetTexture(ShaderStage::FRAGMENT, albedo, 0);
            encoder.SetTexture(ShaderStage::FRAGMENT, normal, 1);
            encoder.SetTexture(ShaderStage::FRAGMENT, orm, 2);
            encoder.DrawIndexed(MTLPrimitiveTypeTriangle, entity.Mesh.IndexBuffer, mesh.IndexCount, mesh.IndexOffset * sizeof(uint32_t));
        }
    }
    encoder.End();
}
