#include "blit_encoder.h"

BlitEncoder::BlitEncoder(id<MTLCommandBuffer> commandBuffer, NSString* label)
{
    m_BlitEncoder = [commandBuffer blitCommandEncoder];
    [m_BlitEncoder setLabel:label];
}

void BlitEncoder::CopyTexture(id<MTLTexture> source, id<MTLTexture> destination)
{
    [m_BlitEncoder copyFromTexture:source toTexture:destination];
}

void BlitEncoder::CopyTexture(const Texture& source, const Texture& destination)
{
    CopyTexture(source.GetTexture(), destination.GetTexture());
}

void BlitEncoder::End()
{
    [m_BlitEncoder endEncoding];
}
