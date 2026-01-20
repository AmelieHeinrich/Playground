#include "IndirectCommandBuffer.h"
#include "Metal/Device.h"
#include "Metal/ResidencySet.h"

#include <Metal/Metal.h>

IndirectCommandBuffer::~IndirectCommandBuffer()
{
    if (m_CommandBuffer) {
        Device::GetResidencySet().RemoveResource(m_CommandBuffer);
    }
}

void IndirectCommandBuffer::Initialize(bool inherit, MTLIndirectCommandType commandType, uint maxCommandCount)
{
    MTLIndirectCommandBufferDescriptor* descriptor = [[MTLIndirectCommandBufferDescriptor alloc] init];
    descriptor.commandTypes = commandType;
    descriptor.inheritBuffers = inherit;
    descriptor.inheritPipelineState = YES;

    m_CommandBuffer = [Device::GetDevice() newIndirectCommandBufferWithDescriptor:descriptor maxCommandCount:maxCommandCount options:MTLResourceStorageModeShared];
    m_CommandBuffer.label = @"Indirect Command Buffer";

    uint64_t resourceID = m_CommandBuffer.gpuResourceID._impl;

    m_Buffer.Initialize(sizeof(uint64_t));
    m_Buffer.Write(&resourceID, sizeof(uint64_t));

    Device::GetResidencySet().AddResource(m_CommandBuffer);
}

void IndirectCommandBuffer::SetLabel(NSString* label)
{
    m_CommandBuffer.label = label;
    m_Buffer.SetLabel([NSString stringWithFormat:@"%@ Buffer Wrapper", label]);
}
