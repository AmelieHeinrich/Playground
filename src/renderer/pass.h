#pragma once

#include "metal/command_buffer.h"

class Pass
{
public:
    virtual ~Pass() = default;

    virtual void Resize(int width, int height) = 0;
    virtual void Render(CommandBuffer& cmdBuffer) = 0;
    virtual void DebugUI() = 0;
};
