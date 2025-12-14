#pragma once

#include "asset/mesh_loader.h"
#include "metal/residency_set.h"
#include "metal/texture.h"
#include "renderer/world.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    #import "core/ios_input.h"
#else
    #import <Cocoa/Cocoa.h>
    #import "core/macos_input.h"
#endif

#include "metal/device.h"
#include "metal/graphics_pipeline.h"
#include "core/camera.h"
#include "renderer/renderer.h"

class API_AVAILABLE(macos(15.0), ios(16.0)) Application
{
public:
    Application();
    virtual ~Application();

    // Initialize with Metal device
    bool Initialize(id<MTLDevice> device);

    // Event callbacks
    void OnResize(uint32_t width, uint32_t height);

    // Update callback - called before rendering
    void OnUpdate(float deltaTime);

    // UI callback - override this to draw ImGui UI
    virtual void OnUI();

    // Rendering - now called by delegate, takes command buffer and drawable
    // Can create any encoder type (render, compute, blit, acceleration structure, etc.)
    // Delegate will handle presentation in a separate command buffer after this
    void OnRender(id<CAMetalDrawable> drawable);

    Camera& GetCamera() { return m_Camera; }
    const Camera& GetCamera() const { return m_Camera; }

    float GetRenderScale() const { return m_RenderScale; }

private:
    id<MTLDevice> m_Device;
    id<MTLCommandQueue> m_CommandQueue;
    ResidencySet m_ResidencySet;

    uint32_t m_Width;
    uint32_t m_Height;
    float m_RenderScale;
    uint32_t m_LastRenderWidth;
    uint32_t m_LastRenderHeight;

    World* m_World;
    Camera m_Camera;
    Renderer* m_Renderer;

#if TARGET_OS_IPHONE
    IOSInput m_Input;
#else
    MacOSInput m_Input;
#endif
};
