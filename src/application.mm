#include "Application.h"
#include "Core/Logger.h"
#include "Metal/Fence.h"
#include "Asset/AstcLoader.h"
#include "Asset/TextureCache.h"
#include "Metal/CommandBuffer.h"
#include "Metal/GraphicsPipeline.h"
#include "Metal/Shader.h"
#include "Renderer/Passes/DebugRenderer.h"
#include "Renderer/Renderer.h"
#include "Swift/CVarRegistry.h"
#include "Swift/ActionsBridge.h"

#include <simd/simd.h>

Application::Application()
    : m_Device(nil)
    , m_CommandQueue(nil)
    , m_Width(0)
    , m_Height(0)
    , m_RenderScaleEnum(2)  // Default to 75%
    , m_LastRenderWidth(0)
    , m_LastRenderHeight(0)
    , m_Camera()
    , m_Input()
    , m_LightsToAdd(10)
{
}

// Helper function to convert enum to scale
static float RenderScaleEnumToFloat(int scaleEnum)
{
    switch (scaleEnum) {
        case 0: return 0.25f;  // 25%
        case 1: return 0.5f;   // 50%
        case 2: return 0.75f;  // 75%
        case 3: return 1.0f;   // 100% (Native)
        default: return 0.75f;
    }
}

Application::~Application()
{
    delete m_World;
    delete m_Renderer;

    TextureCache::Shutdown();
    m_CommandQueue = nil;
    m_Device = nil;
}

bool Application::Initialize(id<MTLDevice> device)
{
    if (!device) {
        LOG_ERROR("Failed to initialize: Metal device is nil");
        return false;
    }

    m_Device = device;
    Device::SetDevice(m_Device);

    // Create command queue
    m_CommandQueue = [m_Device newCommandQueue];
    if (!m_CommandQueue) {
        LOG_ERROR("Failed to create Metal command queue");
        return false;
    }
    Device::SetCommandQueue(m_CommandQueue);

    // Residency set
    m_ResidencySet.Initialize();
    [m_CommandQueue addResidencySet:m_ResidencySet.GetResidencySet()];
    Device::SetResidencySet(&m_ResidencySet);

    // Shader library
    ShaderLibrary::Initialize(m_Device);

    // Create renderer
    m_Renderer = new Renderer();

    // World
    m_World = new World();
    m_World->AddModel("models/Sponza/Sponza.mesh");

    // Directional light
    m_World->GetDirectionalLight() = {
        true,
        simd::make_float3(0.2f, -1.0f, 0.0f),
        1.0f,
        simd::make_float3(1.0f, 1.0f, 1.0f)
    };

    m_World->Prepare();

    // Register application CVars
    RegisterCVars();

    LOG_INFO_FMT("Application initialized successfully with Metal device: %@", [m_Device name]);
    return true;
}

float Application::GetRenderScale() const
{
    return RenderScaleEnumToFloat(m_RenderScaleEnum);
}

void Application::RegisterCVars()
{
    CVarRegistry* registry = [CVarRegistry shared];
    ActionsBridge* actions = [ActionsBridge shared];
    
    // Directional light settings
    DirectionalLight& dirLight = m_World->GetDirectionalLight();
    
    [registry registerBool:@"Application.DirectionalLightEnabled"
                   pointer:&dirLight.Enabled
               displayName:@"Directional Light Enabled"];
    
    [registry registerFloat:@"Application.DirectionalLightIntensity"
                    pointer:&dirLight.Intensity
                        min:0.0f
                        max:10.0f
                displayName:@"Directional Light Intensity"];
    
    [registry registerVector3:@"Application.DirectionalLightDirection"
                      pointer:&dirLight.Direction
                          min:-1.0f
                          max:1.0f
                  displayName:@"Direction"];
    
    [registry registerVector3:@"Application.DirectionalLightColor"
                      pointer:&dirLight.Color
                          min:0.0f
                          max:1.0f
                  displayName:@"Color"];
    
    // Register actions for point lights
    [actions registerAction:@"Application.AddLights"
                   callback:^{
                       AddRandomLights(10);
                   }
                displayName:@"Add 10 Random Lights"
                   category:@"Lights"];
    
    [actions registerAction:@"Application.Add100Lights"
                   callback:^{
                       AddRandomLights(100);
                   }
                displayName:@"Add 100 Random Lights"
                   category:@"Lights"];
    
    [actions registerAction:@"Application.ClearLights"
                   callback:^{
                       ClearAllLights();
                   }
                displayName:@"Clear All Lights"
                   category:@"Lights"];
    
    LOG_INFO("Application: Registered CVars and Actions");
}

void Application::SetRenderScale(int scaleEnum)
{
    if (scaleEnum >= 0 && scaleEnum <= 3) {
        m_RenderScaleEnum = scaleEnum;
        OnResize(m_Width, m_Height);
    }
}

void Application::ClearAllLights()
{
    m_World->GetLightList().GetPointLights().clear();
    m_InitialLightPositions.clear();
}

void Application::AddRandomLights(int count)
{
    for (int i = 0; i < count; i++) {
        PointLight light;

        // Random position within Sponza bounds
        light.Position = simd::float3{
            -12.0f + static_cast<float>(rand()) / RAND_MAX * 24.0f,
            0.5f + static_cast<float>(rand()) / RAND_MAX * 8.0f,
            -4.0f + static_cast<float>(rand()) / RAND_MAX * 8.0f
        };

        light.Radius = 0.3f + static_cast<float>(rand()) / RAND_MAX * 1.0f;

        // Random bright color (avoid too dark colors by using 0.3 to 1.0 range)
        light.Color = simd::float3{
            0.3f + static_cast<float>(rand()) / RAND_MAX * 0.7f,
            0.3f + static_cast<float>(rand()) / RAND_MAX * 0.7f,
            0.3f + static_cast<float>(rand()) / RAND_MAX * 0.7f
        };

        // Scale up the color for more intensity
        light.Intensity = 1.0 + static_cast<float>(rand()) / RAND_MAX * 5.0f;

        m_World->GetLightList().AddPointLight(light);
        m_InitialLightPositions.push_back(light.Position);
    }
}

void Application::OnResize(uint32_t width, uint32_t height)
{
    // Apply render scale to actual render resolution
    float renderScale = GetRenderScale();
    uint32_t renderWidth = static_cast<uint32_t>(width * renderScale);
    uint32_t renderHeight = static_cast<uint32_t>(height * renderScale);

    // Skip resize if nothing has changed (both window size and render size)
    if (m_Width == width && m_Height == height &&
        m_LastRenderWidth == renderWidth && m_LastRenderHeight == renderHeight) {
            return;
        }

    m_Width = width;
    m_Height = height;

    if (height > 0) {
        float aspectRatio = static_cast<float>(width) / static_cast<float>(height);
        m_Camera.SetAspectRatio(aspectRatio);
    }

    // Only resize render targets if the actual render dimensions changed
    if (m_LastRenderWidth != renderWidth || m_LastRenderHeight != renderHeight) {
        m_Renderer->Resize(renderWidth, renderHeight);
        m_LastRenderWidth = renderWidth;
        m_LastRenderHeight = renderHeight;
        LOG_INFO_FMT("Render targets resized to: %ux%u (%.0f%%)", renderWidth, renderHeight, GetRenderScale() * 100.0f);
    }

    LOG_INFO_FMT("Application resized to: %ux%u", width, height);
}

void Application::OnUpdate(float deltaTime)
{
    m_ResidencySet.Update();
    m_Renderer->Prepare();

    // Animate lights
    m_TimeAccumulator += deltaTime;
    auto& lights = m_World->GetLightList().GetPointLights();
    for (size_t i = 0; i < lights.size(); i++) {
        // Use initial position as base and apply circular motion with vertical bobbing
        float timeOffset = i * 0.1f; // Offset each light's animation
        float angle = m_TimeAccumulator * 0.5f + timeOffset;

        simd::float3 offset = simd::float3{
            sinf(angle) * 0.5f,                           // X movement
            sinf(m_TimeAccumulator * 2.0f + timeOffset) * 0.3f,  // Y bobbing
            cosf(angle) * 0.5f                            // Z movement
        };

        lights[i].Position = m_InitialLightPositions[i] + offset;
    }

    m_World->Update(m_Camera);
    // IMPORTANT: Camera must update BEFORE Input.Update() so it can read the mouse delta
    // Input.Update() saves current position as previous for the next frame
    m_Camera.Update(m_Input, deltaTime);
    m_Input.Update(deltaTime);
}

void Application::OnUI()
{
    // UI is now handled by SwiftUI - this method is kept for compatibility
}

void Application::OnRender(id<CAMetalDrawable> drawable)
{
    if (!drawable) {
        return;
    }

    CommandBuffer cmdBuffer;
    cmdBuffer.SetDrawable(drawable.texture);
    m_Renderer->Render(cmdBuffer, *m_World, m_Camera);
    cmdBuffer.Commit();
    [cmdBuffer.GetCommandBuffer() waitUntilCompleted];
}
