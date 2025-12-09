#include "application.h"
#include "asset/astc_loader.h"
#include "asset/texture_cache.h"
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

    // Test pipeline
    GraphicsPipelineDesc desc;
    desc.Path = "shaders/model.metal";
    desc.ColorFormats = {MTLPixelFormatBGRA8Unorm};
    desc.DepthEnabled = true;
    desc.DepthFormat = MTLPixelFormatDepth32Float;
    desc.DepthFunc = MTLCompareFunctionLess;

    m_GraphicsPipeline = GraphicsPipeline::Create(desc);
    m_Model.Load("models/Sponza/Sponza.mesh");

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

    // Resize depth buffer
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:m_Width height:m_Height mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget;
    m_DepthBuffer = [m_Device newTextureWithDescriptor:descriptor];
    if (!m_DepthBuffer) {
        NSLog(@"Failed to resize Metal depth buffer");
        return;
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

#if !TARGET_OS_IPHONE
    ImGui::Separator();
    ImGui::Text("Camera Controls");
    ImGui::Text("WASD - Move, Space/Shift - Up/Down");
    ImGui::Text("Right Mouse Button - Look Around");
#endif

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
    renderPassDescriptor.depthAttachment.texture = m_DepthBuffer;
    renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
    renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;
    renderPassDescriptor.depthAttachment.clearDepth = 1.0;

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
    [renderEncoder setDepthStencilState:m_GraphicsPipeline.GetDepthStencilState()];
    [renderEncoder setVertexBytes:&matrix length:sizeof(matrix) atIndex:0];
    for (auto& mesh : m_Model.Meshes) {
        id<MTLTexture> albedo = m_Model.Textures[m_Model.Materials[mesh.MaterialIndex].AlbedoIndex].Texture;

        [renderEncoder setVertexBuffer:mesh.VertexBuffer offset:0 atIndex:1];
        [renderEncoder setFragmentTexture:albedo atIndex:0];
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:mesh.IndexCount indexType:MTLIndexTypeUInt32 indexBuffer:mesh.IndexBuffer indexBufferOffset:mesh.IndexOffset * sizeof(uint32_t)];
    }
    [renderEncoder endEncoding];
}
