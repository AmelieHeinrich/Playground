#include "application.h"
#import <MetalKit/MetalKit.h>

Application::Application()
    : m_Device(nil)
    , m_CommandQueue(nil)
    , m_Width(0)
    , m_Height(0)
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
    
    // Create command queue
    m_CommandQueue = [m_Device newCommandQueue];
    if (!m_CommandQueue) {
        NSLog(@"Failed to create Metal command queue");
        return false;
    }
    
    NSLog(@"Application initialized successfully with Metal device: %@", [m_Device name]);
    return true;
}

void Application::OnResize(uint32_t width, uint32_t height)
{
    m_Width = width;
    m_Height = height;
    NSLog(@"Application resized to: %ux%u", width, height);
}

void Application::OnRender(id<CAMetalDrawable> drawable)
{
    if (!drawable) {
        return;
    }
    
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [m_CommandQueue commandBuffer];
    
    // Set up render pass descriptor with a simple clear color
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
    
    // Create render command encoder
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    // For now, we just clear the screen - add your rendering code here
    
    [renderEncoder endEncoding];
    
    // Present drawable
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}