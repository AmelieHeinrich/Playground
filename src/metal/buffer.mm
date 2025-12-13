#include "buffer.h"
#include "device.h"

Buffer::Buffer(const void* data, uint64_t size)
{
    Initialize(data, size);
}

Buffer::Buffer(uint64_t size)
{
    Initialize(size);
}

Buffer::~Buffer()
{
    if (!m_Buffer) return;
    Device::GetResidencySet().RemoveResource(m_Buffer);
    m_Buffer = nil;
}

void Buffer::Initialize(const void* data, uint64_t size)
{
    m_Buffer = [Device::GetDevice() newBufferWithBytes:data length:size options:MTLResourceStorageModeShared];
    Device::GetResidencySet().AddResource(m_Buffer);
}

void Buffer::Initialize(uint64_t size)
{
    m_Buffer = [Device::GetDevice() newBufferWithLength:size options:MTLResourceStorageModeShared];
    Device::GetResidencySet().AddResource(m_Buffer);
}
