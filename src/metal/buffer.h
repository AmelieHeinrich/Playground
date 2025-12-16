#pragma once

#include <stdint.h>

#import <Metal/Metal.h>

class Buffer
{
public:
    Buffer() = default;
    Buffer(const void* data, uint64_t size);
    Buffer(uint64_t size);
    ~Buffer();

    void Initialize(const void* data, uint64_t size);
    void Initialize(uint64_t size);

    void SetLabel(NSString* label) { m_Buffer.label = label; }
    id<MTLBuffer> GetBuffer() const { return m_Buffer; }

    uint64_t GetResourceID() const { return (uint64_t)m_Buffer.gpuAddress; }

    void* Contents() const { return [m_Buffer contents]; }
    void Write(const void* data, uint64_t size);
private:
    id<MTLBuffer> m_Buffer = nil;
};
