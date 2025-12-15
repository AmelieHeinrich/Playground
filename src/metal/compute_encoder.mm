#include "compute_encoder.h"

ComputeEncoder::ComputeEncoder(id<MTLCommandBuffer> buffer, NSString* label)
{
    m_Encoder = [buffer computeCommandEncoder];
    [m_Encoder setLabel:label];
}

void ComputeEncoder::End()
{
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
    [m_Encoder dispatchThreadgroups:numGroups threadsPerThreadgroup:threadsPerGroup];
}
