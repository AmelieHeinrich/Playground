#include "renderer.h"

#include "passes/cluster_cull.h"

#include "passes/forward_plus.h"
#include "passes/tonemap.h"
#include "passes/debug_renderer.h"

#include "resource_io.h"

Renderer::Renderer()
{
    ResourceIO::Initialize();

    m_Passes = {
        new ClusterCullPass(),
        new ForwardPlusPass(),
        new DebugRendererPass(),
        new TonemapPass(),
    };
}

Renderer::~Renderer()
{
    for (auto pass : m_Passes) {
        delete pass;
    }

    ResourceIO::Shutdown();
}

void Renderer::Prepare()
{
    for (auto pass : m_Passes) {
        pass->Prepare();
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
