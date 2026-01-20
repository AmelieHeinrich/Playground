#include "Renderer.h"

#include "Passes/ClusterCull.h"
#include "Passes/Tonemap.h"
#include "Passes/DebugRenderer.h"
#include "Passes/GBuffer.h"
#include "Passes/Deferred.h"
#include "Passes/Shadows.h"
#include "Passes/HiZ.h"
#include "Passes/Reflections.h"
#include "Passes/SkyDraw.h"
#include "ResourceIo.h"

Renderer::Renderer()
{
    ResourceIO::Initialize();

    m_Passes = {
        new ClusterCullPass(),
        new GBufferPass(),
        new HiZPass(),
        new ShadowPass(), // Needs to be after GBuffer because raytraced shadows uses depth and normal
        new DeferredPass(),
        new SkyDrawPass(),
        new ReflectionPass(),
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
