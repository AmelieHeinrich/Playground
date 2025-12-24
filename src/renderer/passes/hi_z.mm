#include "hi_z.h"
#include "gbuffer.h"

#include "renderer/resource_io.h"

HiZPass::HiZPass()
{
    // Pipeline
    m_ComputePipeline.Initialize("generate_hiz");

    // HiZ texture
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                                                       width:1
                                                                                      height:1
                                                                                     mipmapped:YES];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    ResourceIO::CreateTexture(HI_Z_MIPCHAIN, descriptor);
}

void HiZPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(HI_Z_MIPCHAIN).Resize(width / 2, height / 2, true);
}

void HiZPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& mipChain = ResourceIO::GetTexture(HI_Z_MIPCHAIN);
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Hi-Z Generation");
    encoder.SetPipeline(m_ComputePipeline);
    for (int i = 0; i < mipChain.MipLevels(); i++) {
        Texture& src = (i == 0) ? depth : mipChain.ViewMip(i - 1);
        Texture& dst = mipChain.ViewMip(i);

        uint x = (dst.Width() + 7) / 8;
        uint y = (dst.Height() + 7) / 8;

        encoder.SetTexture(src, 0);
        encoder.SetTexture(dst, 1);
        encoder.Dispatch(MTLSizeMake(x, y, 1), MTLSizeMake(8, 8, 1));
    }
    encoder.End();
}
