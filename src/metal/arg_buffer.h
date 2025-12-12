#pragma once

#import <Metal/Metal.h>

#include "buffer.h"

#include <vector>

class ArgBuffer
{
public:
    ArgBuffer() = default;
    ArgBuffer(id<MTLFunction> function, int index);
    ~ArgBuffer() = default;

    void Initialize(id<MTLFunction> function, int index);

    void SetBuffer(id<MTLBuffer> buffer, int offset, int index);
    void SetBuffer(const Buffer& buffer, int offset, int index);

    Buffer GetBuffer() const { return m_Buffer; }
    id<MTLArgumentEncoder> GetArgumentEncoder() const { return m_ArgumentEncoder; }

private:
    Buffer m_Buffer;
    id<MTLArgumentEncoder> m_ArgumentEncoder;
};
