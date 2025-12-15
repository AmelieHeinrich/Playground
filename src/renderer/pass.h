#pragma once

#include "core/camera.h"
#include "metal/command_buffer.h"

#include "world.h"

class Pass
{
public:
    virtual ~Pass() = default;

    virtual void Prepare() {}
    virtual void Resize(int width, int height) {}
    virtual void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) = 0;
    virtual void DebugUI() {}
};
