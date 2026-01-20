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
#include "Swift/CVarRegistry.h"
#include "Core/Logger.h"

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
    
    // Register CVars for all passes (one-time registration)
    LOG_INFO("Registering CVars for all passes...");
    for (auto pass : m_Passes) {
        pass->RegisterCVars();
    }
    
    CVarRegistry* registry = [CVarRegistry shared];
    NSArray<NSDictionary*>* allCVars = [registry allCVars];
    LOG_INFO_FMT("Total registered CVars: %lu", (unsigned long)allCVars.count);
    
    for (NSDictionary* cvar in allCVars) {
        NSString* key = cvar[@"key"];
        NSString* displayName = cvar[@"displayName"];
        NSNumber* typeNum = cvar[@"type"];
        LOG_INFO_FMT("  CVar: '%@' -> '%@' (type: %d)", key, displayName, [typeNum intValue]);
    }
    
    NSArray<NSString*>* categories = [registry allCategories];
    LOG_INFO_FMT("CVar categories: %lu", (unsigned long)categories.count);
    for (NSString* category in categories) {
        NSArray* cvars = [registry cvarsForCategory:category];
        LOG_INFO_FMT("  Category '%@': %lu CVars", category, (unsigned long)cvars.count);
    }
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
