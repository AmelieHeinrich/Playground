#pragma once

#include "core/camera.h"
#include "metal/command_buffer.h"

#include "world.h"

class Pass
{
public:
    virtual ~Pass() = default;

    virtual void Resize(int width, int height) = 0;
    virtual void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) = 0;
    virtual void DebugUI() = 0;
};
