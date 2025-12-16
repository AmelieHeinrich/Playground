#include "blit_encoder.h"
#include <Foundation/Foundation.h>

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

void BlitEncoder::FillBuffer(id<MTLBuffer> buffer, uint value)
{
    [m_BlitEncoder fillBuffer:buffer range:NSMakeRange(0, buffer.allocatedSize) value:(uint8_t)value];
}

void BlitEncoder::FillBuffer(const Buffer& buffer, uint value)
{
    FillBuffer(buffer.GetBuffer(), value);
}

void BlitEncoder::End()
{
    [m_BlitEncoder endEncoding];
}

void BlitEncoder::OptimizeIndirectCommandBuffer(const IndirectCommandBuffer& indirectCommandBuffer, uint count)
{
    [m_BlitEncoder optimizeIndirectCommandBuffer:indirectCommandBuffer.GetCommandBuffer() withRange:NSMakeRange(0, count)];
}

void BlitEncoder::ResetIndirectCommandBuffer(const IndirectCommandBuffer& indirectCommandBuffer, uint count)
{
    [m_BlitEncoder resetCommandsInBuffer:indirectCommandBuffer.GetCommandBuffer() withRange:NSMakeRange(0, count)];
}
