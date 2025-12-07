#pragma once

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

class Application {
public:
    Application();
    ~Application();
    
    // Initialize with Metal device
    bool Initialize(id<MTLDevice> device);
    
    // Event callbacks
    void OnResize(uint32_t width, uint32_t height);
    
    // Rendering
    void OnRender(id<CAMetalDrawable> drawable);
    
private:
    id<MTLDevice> m_Device;
    id<MTLCommandQueue> m_CommandQueue;
    
    uint32_t m_Width;
    uint32_t m_Height;
};