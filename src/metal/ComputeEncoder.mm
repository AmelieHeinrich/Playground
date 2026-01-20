#include "ComputeEncoder.h"
#import "Swift/DebugBridge.h"

ComputeEncoder::ComputeEncoder(id<MTLCommandBuffer> buffer, NSString* label, Fence* fence)
    : m_Fence(fence)
{
    m_Encoder = [buffer computeCommandEncoder];
    [m_Encoder setLabel:label];
    
    // Track encoder in Debug Bridge
    [[DebugBridge shared] beginEncoder:label type:EncoderTypeCompute];
}

void ComputeEncoder::End()
{
    [[DebugBridge shared] endEncoder];
    [m_Encoder endEncoding];
}

void ComputeEncoder::SetPipeline(const ComputePipeline& pipeline)
{
    [m_Encoder setComputePipelineState:pipeline.GetPipelineState()];
}

void ComputeEncoder::SetBytes(const void* bytes, size_t length, int index)
{
    [m_Encoder setBytes:bytes length:length atIndex:index];
}

void ComputeEncoder::SetBuffer(id<MTLBuffer> buffer, int index, size_t offset)
{
    [m_Encoder setBuffer:buffer offset:offset atIndex:index];
}

void ComputeEncoder::SetBuffer(const Buffer& buffer, int index, size_t offset)
{
    [m_Encoder setBuffer:buffer.GetBuffer() offset:offset atIndex:index];
}

void ComputeEncoder::SetTexture(id<MTLTexture> texture, int index)
{
    [m_Encoder setTexture:texture atIndex:index];
}

void ComputeEncoder::SetTexture(const Texture& texture, int index)
{
    [m_Encoder setTexture:texture.GetTexture() atIndex:index];
}

void ComputeEncoder::ResourceBarrier(const Buffer& buffer)
{
    id<MTLBuffer> bufferObj = buffer.GetBuffer();
    [m_Encoder memoryBarrierWithResources:&bufferObj count:1];
}

void ComputeEncoder::ResourceBarrier(const Texture& texture)
{
    id<MTLTexture> textureObj = texture.GetTexture();
    [m_Encoder memoryBarrierWithResources:&textureObj count:1];
}

void ComputeEncoder::ResourceBarrier(const IndirectCommandBuffer& buffer)
{
    id<MTLResource> resources[2] = {
        buffer.GetBuffer().GetBuffer(),
        buffer.GetCommandBuffer()
    };
    [m_Encoder memoryBarrierWithResources:resources count:2];
}

void ComputeEncoder::PushGroup(NSString* string)
{
    [m_Encoder pushDebugGroup:string];
}

void ComputeEncoder::PopGroup()
{
    [m_Encoder popDebugGroup];
}

void ComputeEncoder::Dispatch(MTLSize numGroups, MTLSize threadsPerGroup)
{
    [[DebugBridge shared] recordDispatch:numGroups threadsPerGroup:threadsPerGroup];
    [m_Encoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadsPerGroup];
}

void ComputeEncoder::SignalFence()
{
    if (m_Fence && m_Fence->IsValid()) {
        [m_Encoder updateFence:m_Fence->GetFence()];
    }
}

void ComputeEncoder::WaitForFence()
{
    if (m_Fence && m_Fence->IsValid()) {
        [m_Encoder waitForFence:m_Fence->GetFence()];
    }
}
