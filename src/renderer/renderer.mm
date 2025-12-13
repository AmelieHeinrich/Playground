#include "renderer.h"

#include "passes/forward_plus.h"
#include "passes/tonemap.h"

Renderer::Renderer()
{
    m_Passes = {
        new ForwardPlusPass(),
        new TonemapPass()
    };
}

Renderer::~Renderer()
{
    for (auto pass : m_Passes) {
        delete pass;
    }
}

void Renderer::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    for (auto pass : m_Passes) {
        pass->Render(cmdBuffer, world, camera);
    }
}

void Renderer::Resize(int width, int height)
{
    for (auto pass : m_Passes) {
        pass->Resize(width, height);
    }
}

void Renderer::DebugUI()
{
    for (auto pass : m_Passes) {
        pass->DebugUI();
    }
}
