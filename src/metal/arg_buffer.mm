#include "arg_buffer.h"
#include "metal/device.h"

ArgBuffer::ArgBuffer(id<MTLFunction> function, int index)
{
    Initialize(function, index);
}

void ArgBuffer::Initialize(id<MTLFunction> function, int index)
{
    m_ArgumentEncoder = [function newArgumentEncoderWithBufferIndex:index];
    m_Buffer.Initialize(m_ArgumentEncoder.encodedLength);
}

void ArgBuffer::SetBuffer(id<MTLBuffer> buffer, int offset, int index)
{
    [m_ArgumentEncoder setBuffer:buffer offset:offset atIndex:index];
}

void ArgBuffer::SetBuffer(const Buffer& buffer, int offset, int index)
{
    SetBuffer(buffer.GetBuffer(), offset, index);
}
