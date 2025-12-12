#include "command_buffer.h"
#include "device.h"

CommandBuffer::CommandBuffer(NSString* name)
{
    m_CommandBuffer = [Device::GetCommandQueue() commandBuffer];
    m_CommandBuffer.label = name;
}

void CommandBuffer::Commit()
{
    [m_CommandBuffer commit];
}
