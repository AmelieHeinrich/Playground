#include "reflections.h"
#include "gbuffer.h"
#include "deferred.h"
#include "hi_z.h"

#include "renderer/resource_io.h"

#include <Metal/Metal.h>


ReflectionPass::ReflectionPass()
{
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    m_OutputTexture.Initialize(descriptor);
    m_OutputTexture.SetLabel(@"Reflection Output");

    m_SSMirrorKernel.Initialize("ssmirror_reflections_cs");
}

void ReflectionPass::Resize(int width, int height)
{
    m_OutputTexture.Resize(width, height);
}

void ReflectionPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    switch (m_Technique) {
        case ReflectionTechnique::NONE:
            break;
        case ReflectionTechnique::SCREEN_SPACE_MIRROR:
            ScreenSpaceMirror(cmdBuffer, world, camera);
            break;
        case ReflectionTechnique::SCREEN_SPACE_GLOSSY:
            ScreenSpaceGlossy(cmdBuffer, world, camera);
            break;
        case ReflectionTechnique::HYBRID_MIRROR:
            HybridMirror(cmdBuffer, world, camera);
            break;
        case ReflectionTechnique::HYBRID_GLOSSY:
            HybridGlossy(cmdBuffer, world, camera);
            break;
    }
}

void ReflectionPass::DebugUI()
{
    // UI is now handled by SwiftUI
}

void ReflectionPass::ScreenSpaceMirror(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& normalTexture = ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT);
    Texture& hiZTexture = ResourceIO::GetTexture(HI_Z_MIPCHAIN);
    Texture& pbrTexture = ResourceIO::GetTexture(GBUFFER_PBR_OUTPUT);
    Texture& albedoTexture = ResourceIO::GetTexture(GBUFFER_ALBEDO_OUTPUT);
    Texture& deferredTexture = ResourceIO::GetTexture(DEFERRED_COLOR);

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Reflections (Screen Space Mirror)");
    encoder.SetPipeline(m_SSMirrorKernel);
    encoder.SetBuffer(world.GetSceneAB(), 0);
    encoder.SetTexture(normalTexture, 0);
    encoder.SetTexture(hiZTexture, 1);
    encoder.SetTexture(world.GetSkybox(), 2);
    encoder.SetTexture(pbrTexture, 3);
    encoder.SetTexture(albedoTexture, 4);
    encoder.SetTexture(deferredTexture, 5);
    encoder.SetTexture(m_OutputTexture, 6);
    encoder.Dispatch(
        MTLSizeMake((deferredTexture.Width() + 7) / 8, (deferredTexture.Height() + 7) / 8, 1),
        MTLSizeMake(8, 8, 1)
    );
    encoder.End();

    BlitEncoder copyToDeferred = cmdBuffer.BlitPass(@"Copy to Deferred");
    copyToDeferred.CopyTexture(m_OutputTexture, deferredTexture);
    copyToDeferred.End();
}
