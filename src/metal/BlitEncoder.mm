#include "BlitEncoder.h"
#include <Foundation/Foundation.h>
#import "Swift/DebugBridge.h"

BlitEncoder::BlitEncoder(id<MTLCommandBuffer> commandBuffer, NSString* label, Fence* fence)
    : m_Fence(fence)
{
    m_BlitEncoder = [commandBuffer blitCommandEncoder];
    [m_BlitEncoder setLabel:label];
    
    // Track encoder in Debug Bridge
    [[DebugBridge shared] beginEncoder:label type:EncoderTypeBlit];
}

void BlitEncoder::CopyTexture(id<MTLTexture> source, id<MTLTexture> destination)
{
    [[DebugBridge shared] recordCopy];
    [m_BlitEncoder copyFromTexture:source toTexture:destination];
}

void BlitEncoder::CopyTexture(const Texture& source, const Texture& destination)
{
    CopyTexture(source.GetTexture(), destination.GetTexture());
}

void BlitEncoder::FillBuffer(id<MTLBuffer> buffer, uint value)
{
    [[DebugBridge shared] recordCopy];
    [m_BlitEncoder fillBuffer:buffer range:NSMakeRange(0, buffer.allocatedSize) value:(uint8_t)value];
}

void BlitEncoder::FillBuffer(const Buffer& buffer, uint value)
{
    FillBuffer(buffer.GetBuffer(), value);
}

void BlitEncoder::End()
{
    [[DebugBridge shared] endEncoder];
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

void BlitEncoder::SignalFence()
{
    if (m_Fence && m_Fence->IsValid()) {
        [m_BlitEncoder updateFence:m_Fence->GetFence()];
    }
}

void BlitEncoder::WaitForFence()
{
    if (m_Fence && m_Fence->IsValid()) {
        [m_BlitEncoder waitForFence:m_Fence->GetFence()];
    }
}
