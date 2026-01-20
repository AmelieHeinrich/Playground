#pragma once

#include "Core/Camera.h"
#include "Metal/CommandBuffer.h"

#include "World.h"

class Pass
{
public:
    virtual ~Pass() = default;

    virtual void Prepare() {}
    virtual void Resize(int width, int height) {}
    virtual void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) = 0;
    virtual void DebugUI() {}
    virtual void RegisterCVars() {}
};
