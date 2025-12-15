#include "application.h"
#include "asset/astc_loader.h"
#include "asset/texture_cache.h"
#include "metal/command_buffer.h"
#include "metal/graphics_pipeline.h"
#include "metal/shader.h"
#include "renderer/renderer.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include <imgui.h>
#include <simd/simd.h>

Application::Application()
    : m_Device(nil)
    , m_CommandQueue(nil)
    , m_Width(0)
    , m_Height(0)
    , m_RenderScale(1.0f)
    , m_LastRenderWidth(0)
    , m_LastRenderHeight(0)
    , m_Camera()
    , m_Input()
{
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
        NSLog(@"Failed to initialize: Metal device is nil");
        return false;
    }

    m_Device = device;
    Device::SetDevice(m_Device);

    // Create command queue
    m_CommandQueue = [m_Device newCommandQueue];
    if (!m_CommandQueue) {
        NSLog(@"Failed to create Metal command queue");
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

    // Create random lights
    int lightCount = 16;
    for (int i = 0; i < lightCount; i++) {
        PointLight light;

        // Random position within Sponza bounds
        // Sponza is roughly: X: [-12, 12], Y: [0, 15], Z: [-5, 5]
        light.Position = simd::float3{
            -5.0f + static_cast<float>(rand()) / RAND_MAX * 10.0f,
            0.5f + static_cast<float>(rand()) / RAND_MAX * 4.0f,
            -5.0f + static_cast<float>(rand()) / RAND_MAX * 10.0f
        };

        // Random radius between 2 and 8
        light.Radius = 2.0f + static_cast<float>(rand()) / RAND_MAX * 6.0f;

        // Random bright color (avoid too dark colors by using 0.3 to 1.0 range)
        light.Color = simd::float3{
            0.3f + static_cast<float>(rand()) / RAND_MAX * 0.7f,
            0.3f + static_cast<float>(rand()) / RAND_MAX * 0.7f,
            0.3f + static_cast<float>(rand()) / RAND_MAX * 0.7f
        };

        // Scale up the color for more intensity
        light.Color *= 10.0f;

        m_World->GetLightList().AddPointLight(light);
    }

    NSLog(@"Application initialized successfully with Metal device: %@", [m_Device name]);
    return true;
}

void Application::OnResize(uint32_t width, uint32_t height)
{
    @autoreleasepool {
        // Apply render scale to actual render resolution
        uint32_t renderWidth = static_cast<uint32_t>(width * m_RenderScale);
        uint32_t renderHeight = static_cast<uint32_t>(height * m_RenderScale);

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
            NSLog(@"Render targets resized to: %ux%u (%.0f%%)", renderWidth, renderHeight, m_RenderScale * 100.0f);
        }

        NSLog(@"Application resized to: %ux%u", width, height);
    }
}

void Application::OnUpdate(float deltaTime)
{
    @autoreleasepool {
        m_ResidencySet.Update();
        m_World->Update();
        m_Input.Update(deltaTime);
        m_Camera.Update(m_Input, deltaTime);
    }
}

void Application::OnUI()
{
    ImGui::Begin("Application");
    ImGui::Text("Metal Playground by Amélie Heinrich");
    ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);

#if !TARGET_OS_IPHONE
    ImGui::Separator();
    ImGui::Text("Camera Controls");
    ImGui::Text("WASD - Move, Space/Shift - Up/Down");
    ImGui::Text("Right Mouse Button - Look Around");
#endif

    ImGui::Separator();
    
    const float scales[] = { 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f };
    const char* labels[] = { "50%", "75%", "100%", "125%", "150%", "200%" };
    
    // Find current selection index
    int currentIndex = 2; // Default to 100%
    for (int i = 0; i < 6; i++) {
        if (m_RenderScale == scales[i]) {
            currentIndex = i;
            break;
        }
    }
    
    ImGui::Text("Render Scale");
    if (ImGui::Combo("##RenderScale", &currentIndex, labels, 6)) {
        m_RenderScale = scales[currentIndex];
        OnResize(m_Width, m_Height);
    }

    ImGui::Separator();
    m_Renderer->DebugUI();
    ImGui::End();
}

void Application::OnRender(id<CAMetalDrawable> drawable)
{
    @autoreleasepool {
        if (!drawable) {
            return;
        }

        CommandBuffer cmdBuffer;
        cmdBuffer.SetDrawable(drawable.texture);
        m_Renderer->Render(cmdBuffer, *m_World, m_Camera);
        cmdBuffer.Commit();
    }
}
