#include "application.h"
#include "asset/astc_loader.h"
#include "asset/texture_cache.h"
#include "metal/command_buffer.h"
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
    Device::SetCommandQueue(m_CommandQueue);

    // Residency set
    m_ResidencySet.Initialize();
    [m_CommandQueue addResidencySet:m_ResidencySet.GetResidencySet()];
    Device::SetResidencySet(&m_ResidencySet);

    // Set descriptor
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:m_Width height:m_Height mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget;
    m_DepthBuffer.SetDescriptor(descriptor);

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
    m_DepthBuffer.Resize(m_Width, m_Height);

    NSLog(@"Application resized to: %ux%u", width, height);
}

void Application::OnUpdate(float deltaTime)
{
    m_ResidencySet.Update();

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

void Application::OnRender(id<CAMetalDrawable> drawable)
{
    if (!drawable) {
        return;
    }

    matrix_float4x4 matrix = m_Camera.GetViewProjectionMatrix();
    CommandBuffer cmdBuffer;
    
    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(drawable.texture)
                                                 .AddDepthStencilTexture(m_DepthBuffer)
                                                 .SetName(@"Forward Pass"));
    encoder.SetGraphicsPipeline(m_GraphicsPipeline);
    encoder.SetBytes(ShaderStage::VERTEX, &matrix, sizeof(matrix), 0);
    for (auto& mesh : m_Model.Meshes) {
        id<MTLTexture> albedo = m_Model.Textures[m_Model.Materials[mesh.MaterialIndex].AlbedoIndex].Texture;

        encoder.SetBuffer(ShaderStage::VERTEX, mesh.VertexBuffer, 1);
        encoder.SetTexture(ShaderStage::FRAGMENT, albedo, 0);
        encoder.DrawIndexed(MTLPrimitiveTypeTriangle, mesh.IndexBuffer, mesh.IndexCount, mesh.IndexOffset * sizeof(uint32_t));
    }
    encoder.End();

    cmdBuffer.Commit();
}
