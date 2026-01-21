#pragma once

#include "Asset/MeshLoader.h"
#include "Metal/ResidencySet.h"
#include "Metal/Texture.h"
#include "Renderer/World.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    #import "Core/IosInput.h"
#else
    #import <Cocoa/Cocoa.h>
    #import "Core/MacosInput.h"
#endif

#include "Metal/Device.h"
#include "Metal/GraphicsPipeline.h"
#include "Core/Camera.h"
#include "Renderer/Renderer.h"

class API_AVAILABLE(macos(15.0), ios(16.0)) Application
{
public:
    Application();
    virtual ~Application();

    // Initialize with Metal device
    bool Initialize(id<MTLDevice> device);
    
    // Register console variables
    void RegisterCVars();

    // Event callbacks
    void OnResize(uint32_t width, uint32_t height);

    // Update callback - called before rendering
    void OnUpdate(float deltaTime);

    // UI callback - kept for compatibility (UI is now handled by SwiftUI)
    virtual void OnUI();

    // Rendering - takes the drawable and handles presentation internally
    // Creates a command buffer and can use any encoder type (render, compute, blit, acceleration structure, etc.)
    // The application will present the drawable using its own command buffer
    void OnRender(id<CAMetalDrawable> drawable);

    Camera& GetCamera() { return m_Camera; }
    const Camera& GetCamera() const { return m_Camera; }

    int GetRenderScaleEnum() const { return m_RenderScaleEnum; }
    float GetRenderScale() const;
    void SetRenderScale(int scaleEnum);

    // Accessors for SwiftUI bridge
    World* GetWorld() { return m_World; }
    Renderer* GetRenderer() { return m_Renderer; }
    void AddRandomLights(int count);
    void ClearAllLights();

    uint32_t GetOutputWidth() const { return m_Width; }
    uint32_t GetOutputHeight() const { return m_Height; }
    uint32_t GetRenderWidth() const { return m_LastRenderWidth; }
    uint32_t GetRenderHeight() const { return m_LastRenderHeight; }

#if TARGET_OS_IPHONE
    IOSInput& GetInput() { return m_Input; }
#else
    MacOSInput& GetInput() { return m_Input; }
#endif

private:

    id<MTLDevice> m_Device;
    id<MTLCommandQueue> m_CommandQueue;
    ResidencySet m_ResidencySet;

    uint32_t m_Width;
    uint32_t m_Height;
    int m_RenderScaleEnum;  // 0=25%, 1=50%, 2=75%, 3=100%
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

    float m_TimeAccumulator = 0.0f;
    std::vector<simd::float3> m_InitialLightPositions;
    
    // UI state
    int m_LightsToAdd = 10;
};
