#pragma once

#include "core/camera.h"
#include "metal/command_buffer.h"
#include "pass.h"

class Renderer
{
public:
    Renderer();
    ~Renderer();

    void Prepare();
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera);
    void Resize(int width, int height);
    void DebugUI();

    // Get a pass by type (for SwiftUI bridge)
    template<typename T>
    T* GetPass() {
        for (auto* pass : m_Passes) {
            if (T* p = dynamic_cast<T*>(pass)) {
                return p;
            }
        }
        return nullptr;
    }

private:
    std::vector<Pass*> m_Passes;
};
