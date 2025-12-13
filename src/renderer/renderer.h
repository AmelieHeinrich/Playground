#pragma once

#include "core/camera.h"
#include "metal/command_buffer.h"
#include "pass.h"

class Renderer
{
public:
    Renderer();
    ~Renderer();

    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void Resize(int width, int height);
    void DebugUI();
private:
    std::vector<Pass*> m_Passes;
};
