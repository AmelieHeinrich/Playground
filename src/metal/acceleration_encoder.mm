#include "acceleration_encoder.h"

AccelerationEncoder::AccelerationEncoder(id<MTLCommandBuffer> cmdBuffer, NSString* label, Fence* fence)
    : m_Fence(fence)
{
    m_Encoder = [cmdBuffer accelerationStructureCommandEncoder];
    [m_Encoder setLabel:label];
    [m_Encoder waitForFence:fence->GetFence()];
}

void AccelerationEncoder::End()
{
    [m_Encoder updateFence:m_Fence->GetFence()];
    [m_Encoder endEncoding];
}

void AccelerationEncoder::BuildBLAS(BLAS* blas)
{
    [m_Encoder buildAccelerationStructure:blas->GetAccelerationStructure()
               descriptor:blas->GetDescriptor()
               scratchBuffer:blas->GetScratchBuffer()->GetBuffer()
               scratchBufferOffset:0];
}

void AccelerationEncoder::BuildTLAS(TLAS* tlas)
{
    MTLInstanceAccelerationStructureDescriptor* descriptor = tlas->GetDescriptor();
    descriptor.instanceCount = [tlas->GetBLASMap() count];
    descriptor.instancedAccelerationStructures = tlas->GetBLASMap();

    [m_Encoder buildAccelerationStructure:tlas->GetTLAS()
               descriptor:descriptor
               scratchBuffer:tlas->GetScratchBuffer()->GetBuffer()
               scratchBufferOffset:0];
}
