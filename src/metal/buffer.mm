#include "Buffer.h"
#include "Device.h"

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

void Buffer::Write(const void* data, uint64_t size)
{
    void* ptr = [m_Buffer contents];
    memcpy(ptr, data, size);
}

void Buffer::Cleanup()
{
    if (m_Buffer) {
        Device::GetResidencySet().RemoveResource(m_Buffer);
        m_Buffer = nil;
    }
}
