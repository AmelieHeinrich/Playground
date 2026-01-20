#include "AccelerationEncoder.h"
#import "Swift/DebugBridge.h"

AccelerationEncoder::AccelerationEncoder(id<MTLCommandBuffer> cmdBuffer, NSString* label, Fence* fence)
    : m_Fence(fence)
{
    m_Encoder = [cmdBuffer accelerationStructureCommandEncoder];
    [m_Encoder setLabel:label];
    
    // Track encoder in Debug Bridge
    [[DebugBridge shared] beginEncoder:label type:EncoderTypeAcceleration];
}

void AccelerationEncoder::End()
{
    [[DebugBridge shared] endEncoder];
    [m_Encoder endEncoding];
}

void AccelerationEncoder::BuildBLAS(BLAS* blas)
{
    [[DebugBridge shared] recordAccelerationStructureBuild];
    [m_Encoder buildAccelerationStructure:blas->GetAccelerationStructure()
               descriptor:blas->GetDescriptor()
               scratchBuffer:blas->GetScratchBuffer()->GetBuffer()
               scratchBufferOffset:0];
}

void AccelerationEncoder::BuildTLAS(TLAS* tlas)
{
    [[DebugBridge shared] recordAccelerationStructureBuild];
    MTLInstanceAccelerationStructureDescriptor* descriptor = tlas->GetDescriptor();
    descriptor.instanceCount = [tlas->GetBLASMap() count];
    descriptor.instancedAccelerationStructures = tlas->GetBLASMap();

    [m_Encoder buildAccelerationStructure:tlas->GetTLAS()
               descriptor:descriptor
               scratchBuffer:tlas->GetScratchBuffer()->GetBuffer()
               scratchBufferOffset:0];
}
