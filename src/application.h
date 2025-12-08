#pragma once

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#include "metal/device.h"
#include "metal/graphics_pipeline.h"

class Application
{
public:
    Application();
    virtual ~Application();

    // Initialize with Metal device
    bool Initialize(id<MTLDevice> device);

    // Event callbacks
    void OnResize(uint32_t width, uint32_t height);
    
    // UI callback - override this to draw ImGui UI
    virtual void OnUI();

    // Rendering - now called by delegate, takes command buffer and drawable
    // Can create any encoder type (render, compute, blit, acceleration structure, etc.)
    // Delegate will handle presentation in a separate command buffer after this
    void OnRender(id<MTLCommandBuffer> commandBuffer, id<CAMetalDrawable> drawable);

private:
    id<MTLDevice> m_Device;
    id<MTLCommandQueue> m_CommandQueue;

    uint32_t m_Width;
    uint32_t m_Height;

    GraphicsPipeline m_GraphicsPipeline;
};
