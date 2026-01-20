#pragma once

#include "Buffer.h"

class IndirectCommandBuffer
{
public:
    IndirectCommandBuffer() = default;
    ~IndirectCommandBuffer();

    void Initialize(bool inherit, MTLIndirectCommandType commandType, uint maxCommandCount);
    void SetLabel(NSString* label);

    const Buffer& GetBuffer() const { return m_Buffer; }
    id<MTLIndirectCommandBuffer> GetCommandBuffer() const { return m_CommandBuffer; }
private:
    Buffer m_Buffer;
    id<MTLIndirectCommandBuffer> m_CommandBuffer;
};
