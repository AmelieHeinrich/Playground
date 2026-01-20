#include "Buffer.h"
#include "Device.h"
#import "Swift/DebugBridge.h"

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
    
    // Remove from Debug Bridge tracking
    NSString* name = m_Buffer.label ?: [NSString stringWithFormat:@"Buffer_%p", m_Buffer];
    [[DebugBridge shared] removeAllocation:name];
    
    Device::GetResidencySet().RemoveResource(m_Buffer);
}

void Buffer::Initialize(const void* data, uint64_t size)
{
    m_Buffer = [Device::GetDevice() newBufferWithBytes:data length:size options:MTLResourceStorageModeShared];
    Device::GetResidencySet().AddResource(m_Buffer);
    
    // Track allocation in Debug Bridge
    NSString* name = m_Buffer.label ?: [NSString stringWithFormat:@"Buffer_%p", m_Buffer];
    [[DebugBridge shared] trackAllocation:name resource:m_Buffer];
}

void Buffer::Initialize(uint64_t size)
{
    m_Buffer = [Device::GetDevice() newBufferWithLength:size options:MTLResourceStorageModeShared];
    Device::GetResidencySet().AddResource(m_Buffer);
    
    // Track allocation in Debug Bridge
    NSString* name = m_Buffer.label ?: [NSString stringWithFormat:@"Buffer_%p", m_Buffer];
    [[DebugBridge shared] trackAllocation:name resource:m_Buffer];
}

void Buffer::Write(const void* data, uint64_t size)
{
    void* ptr = [m_Buffer contents];
    memcpy(ptr, data, size);
}

void Buffer::Cleanup()
{
    if (m_Buffer) {
        NSString* name = m_Buffer.label ?: [NSString stringWithFormat:@"Buffer_%p", m_Buffer];
        [[DebugBridge shared] removeAllocation:name];
        Device::GetResidencySet().RemoveResource(m_Buffer);
        m_Buffer = nil;
    }
}

void Buffer::SetLabel(NSString* label)
{
    if (m_Buffer) {
        // Remove old tracking entry
        NSString* oldName = m_Buffer.label ?: [NSString stringWithFormat:@"Buffer_%p", m_Buffer];
        [[DebugBridge shared] removeAllocation:oldName];
        
        // Update label
        m_Buffer.label = label;
        
        // Re-track with new name
        [[DebugBridge shared] trackAllocation:label resource:m_Buffer];
    }
}
