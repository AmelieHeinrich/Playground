#pragma once

#import <Metal/Metal.h>

class CommandBuffer
{
public:
    CommandBuffer(NSString* name = @"Command Buffer");
    ~CommandBuffer() = default;

    void Commit();
    id<MTLCommandBuffer> GetCommandBuffer() { return m_CommandBuffer; }
private:
    id<MTLCommandBuffer> m_CommandBuffer;
};
