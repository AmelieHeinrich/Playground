#include "application.h"
#include "metal/graphics_pipeline.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include <imgui.h>
#include <simd/simd.h>

Application::Application()
    : m_Device(nil)
    , m_CommandQueue(nil)
    , m_Width(0)
    , m_Height(0)
    , m_Camera()
    , m_Input()
{
    
}

Application::~Application()
{
    // Release Metal resources
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

    // Test pipeline
    GraphicsPipelineDesc desc;
    desc.Path = "shaders/triangle.metal";
    desc.ColorFormats = {MTLPixelFormatBGRA8Unorm};

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);

    NSLog(@"Application initialized successfully with Metal device: %@", [m_Device name]);
    return true;
}

void Application::OnResize(uint32_t width, uint32_t height)
{
    m_Width = width;
    m_Height = height;
    
    if (height > 0) {
        float aspectRatio = static_cast<float>(width) / static_cast<float>(height);
        m_Camera.SetAspectRatio(aspectRatio);
    }
    
    NSLog(@"Application resized to: %ux%u", width, height);
}

void Application::OnUpdate(float deltaTime)
{
    m_Input.Update(deltaTime);
    m_Camera.Update(m_Input, deltaTime);
}

void Application::OnUI()
{
    ImGui::Begin("Application");
    ImGui::Text("Metal Playground by Amélie Heinrich");
    ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
    
    ImGui::Separator();
    ImGui::Text("Camera Controls");
    ImGui::Text("WASD - Move, Space/Shift - Up/Down");
    ImGui::Text("Right Mouse Button - Look Around");
    
    ImGuiIO& io = ImGui::GetIO();
    if (!io.WantCaptureMouse) {
        ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "Camera Active");
    } else {
        ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "Camera Inactive");
    }
    
    ImGui::Separator();
    vector_float3 pos = m_Camera.GetPosition();
    ImGui::Text("Position: (%.2f, %.2f, %.2f)", pos.x, pos.y, pos.z);
    ImGui::Text("Yaw: %.2f, Pitch: %.2f", m_Camera.GetYaw(), m_Camera.GetPitch());
    
    ImGui::End();
}

void Application::OnRender(id<MTLCommandBuffer> commandBuffer, id<CAMetalDrawable> drawable)
{
    [commandBuffer setLabel:@"Application Render"];
    
    if (!drawable) {
        return;
    }
    
    // Set up render pass descriptor with drawable texture
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // Create a nice gradient-like clear color based on time
    static float hue = 0.0f;
    hue += 0.001f;
    if (hue > 1.0f) hue = 0.0f;

    // Simple animated color (cycling through hues)
    float r = (sin(hue * 6.28318f) + 1.0f) * 0.5f;
    float g = (sin(hue * 6.28318f + 2.094395f) + 1.0f) * 0.5f;
    float b = (sin(hue * 6.28318f + 4.188790f) + 1.0f) * 0.5f;

    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(r * 0.3, g * 0.3, b * 0.3, 1.0);

    matrix_float4x4 matrix = m_Camera.GetViewProjectionMatrix();
    
    // Create render command encoder
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setLabel:@"Triangle Rendering"];
    [renderEncoder setRenderPipelineState:m_GraphicsPipeline.GetPipelineState()];
    [renderEncoder setVertexBytes:&matrix length:sizeof(matrix) atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [renderEncoder endEncoding];
}
