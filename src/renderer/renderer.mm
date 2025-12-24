#include "renderer.h"

#include "passes/cluster_cull.h"
#include "passes/tonemap.h"
#include "passes/debug_renderer.h"
#include "passes/gbuffer.h"
#include "passes/deferred.h"
#include "passes/shadows.h"
#include "passes/hi_z.h"

#include "resource_io.h"

Renderer::Renderer()
{
    ResourceIO::Initialize();

    m_Passes = {
        new ClusterCullPass(),
        new GBufferPass(),
        new HiZPass(),
        new ShadowPass(), // Needs to be after GBuffer because raytraced shadows uses depth and normal
        new DeferredPass(),
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
