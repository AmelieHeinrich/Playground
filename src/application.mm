#include "application.h"
#include "asset/astc_loader.h"
#include "asset/texture_cache.h"
#include "metal/command_buffer.h"
#include "metal/graphics_pipeline.h"
#include "metal/shader.h"
#include "renderer/passes/debug_renderer.h"
#include "renderer/renderer.h"

#import <Metal/Metal.h>
#include <simd/matrix.h>
#import <MetalKit/MetalKit.h>

#include <imgui.h>
#include <simd/simd.h>

Application::Application()
    : m_Device(nil)
    , m_CommandQueue(nil)
    , m_Width(0)
    , m_Height(0)
    , m_RenderScale(1.5f)
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
    int lightCount = 2048;
    for (int i = 0; i < lightCount; i++) {
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

    NSLog(@"Application initialized successfully with Metal device: %@", [m_Device name]);
    return true;
}

void Application::OnResize(uint32_t width, uint32_t height)
{
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

void Application::OnUpdate(float deltaTime)
{
    m_Renderer->Prepare();
    m_ResidencySet.Update();

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

    m_World->Update();
    m_Input.Update(deltaTime);
    m_Camera.Update(m_Input, deltaTime);
}

void Application::OnUI()
{
    ImGui::Begin("Application");
    ImGui::Text("Metal Playground by Amélie Heinrich");
    ImGui::Text("%.3f ms (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);

#if !TARGET_OS_IPHONE
    ImGui::Separator();
    ImGui::Text("Camera Controls");
    ImGui::Text("WASD - Move, Space/Shift - Up/Down");
    ImGui::Text("Right Mouse Button - Look Around");
#endif

    if (ImGui::TreeNodeEx("Renderer Settings", ImGuiTreeNodeFlags_Framed)) {
        ImGui::Separator();

        const float scales[] = { 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f };

        // Calculate actual resolutions for each scale
        uint32_t renderWidth = static_cast<uint32_t>(m_Width * m_RenderScale);
        uint32_t renderHeight = static_cast<uint32_t>(m_Height * m_RenderScale);

        // Create labels with resolution info
        char label0[64], label1[64], label2[64], label3[64], label4[64], label5[64];
        snprintf(label0, sizeof(label0), "50%% (%ux%u)", static_cast<uint32_t>(m_Width * scales[0]), static_cast<uint32_t>(m_Height * scales[0]));
        snprintf(label1, sizeof(label1), "75%% (%ux%u)", static_cast<uint32_t>(m_Width * scales[1]), static_cast<uint32_t>(m_Height * scales[1]));
        snprintf(label2, sizeof(label2), "100%% (%ux%u)", static_cast<uint32_t>(m_Width * scales[2]), static_cast<uint32_t>(m_Height * scales[2]));
        snprintf(label3, sizeof(label3), "125%% (%ux%u)", static_cast<uint32_t>(m_Width * scales[3]), static_cast<uint32_t>(m_Height * scales[3]));
        snprintf(label4, sizeof(label4), "150%% (%ux%u)", static_cast<uint32_t>(m_Width * scales[4]), static_cast<uint32_t>(m_Height * scales[4]));
        snprintf(label5, sizeof(label5), "200%% (%ux%u)", static_cast<uint32_t>(m_Width * scales[5]), static_cast<uint32_t>(m_Height * scales[5]));

        const char* labels[] = { label0, label1, label2, label3, label4, label5 };

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
        ImGui::TreePop();
    }

    ImGui::End();
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
}
