#import "ApplicationBridge.h"

#include "Application.h"
#include "Renderer/Renderer.h"
#include "Renderer/Passes/Shadows.h"
#include "Renderer/Passes/Deferred.h"
#include "Renderer/Passes/Reflections.h"
#include "Renderer/Passes/GBuffer.h"
#include "Renderer/Passes/Tonemap.h"
#include "Renderer/Passes/DebugRenderer.h"

@implementation ApplicationBridge {
    Application* _application;
    CFTimeInterval _lastFrameTime;
    float _fps;
    float _frameTime;
    BOOL _inputEnabled;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        
        _application = new Application();
        if (!_application->Initialize(device)) {
            delete _application;
            return nil;
        }
        
        _fps = 0.0f;
        _frameTime = 0.0f;
        _lastFrameTime = 0.0;
        _inputEnabled = YES; // Input enabled by default
    }
    return self;
}

- (void)dealloc {
    if (_application) {
        delete _application;
        _application = nullptr;
    }
}

#pragma mark - Performance Metrics

- (float)fps {
    return _fps;
}

- (float)frameTime {
    return _frameTime;
}

#pragma mark - Resolution Info

- (NSUInteger)outputWidth {
    return _application->GetOutputWidth();
}

- (NSUInteger)outputHeight {
    return _application->GetOutputHeight();
}

- (NSUInteger)renderWidth {
    return _application->GetRenderWidth();
}

- (NSUInteger)renderHeight {
    return _application->GetRenderHeight();
}

#pragma mark - Render Scale

- (float)renderScale {
    return _application->GetRenderScale();
}

- (void)setRenderScale:(float)renderScale {
    _application->SetRenderScale(renderScale);
}

#pragma mark - Point Lights

- (NSInteger)pointLightCount {
    return _application->GetWorld()->GetLightList().GetPointLights().size();
}

- (void)addRandomLights:(NSInteger)count {
    _application->AddRandomLights((int)count);
}

- (void)clearAllLights {
    _application->ClearAllLights();
}

#pragma mark - Directional Light

- (BOOL)directionalLightEnabled {
    return _application->GetWorld()->GetDirectionalLight().Enabled;
}

- (void)setDirectionalLightEnabled:(BOOL)enabled {
    _application->GetWorld()->GetDirectionalLight().Enabled = enabled;
}

- (simd_float3)directionalLightDirection {
    return _application->GetWorld()->GetDirectionalLight().Direction;
}

- (void)setDirectionalLightDirection:(simd_float3)direction {
    _application->GetWorld()->GetDirectionalLight().Direction = simd::normalize(direction);
}

- (simd_float3)directionalLightColor {
    return _application->GetWorld()->GetDirectionalLight().Color;
}

- (void)setDirectionalLightColor:(simd_float3)color {
    _application->GetWorld()->GetDirectionalLight().Color = color;
}

- (float)directionalLightIntensity {
    return _application->GetWorld()->GetDirectionalLight().Intensity;
}

- (void)setDirectionalLightIntensity:(float)intensity {
    _application->GetWorld()->GetDirectionalLight().Intensity = intensity;
}

#pragma mark - Shadow Pass

- (NSInteger)shadowTechnique {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        return static_cast<NSInteger>(pass->GetTechnique());
    }
    return 0;
}

- (void)setShadowTechnique:(NSInteger)technique {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        pass->SetTechnique(static_cast<ShadowTechnique>(technique));
    }
}

- (NSInteger)shadowResolution {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        ShadowResolution res = pass->GetResolution();
        switch (res) {
            case ShadowResolution::LOW: return 0;
            case ShadowResolution::MEDIUM: return 1;
            case ShadowResolution::HIGH: return 2;
            case ShadowResolution::ULTRA: return 3;
        }
    }
    return 2; // Default to HIGH
}

- (void)setShadowResolution:(NSInteger)resolution {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        ShadowResolution res;
        switch (resolution) {
            case 0: res = ShadowResolution::LOW; break;
            case 1: res = ShadowResolution::MEDIUM; break;
            case 2: res = ShadowResolution::HIGH; break;
            case 3: res = ShadowResolution::ULTRA; break;
            default: res = ShadowResolution::HIGH; break;
        }
        pass->SetResolution(res);
    }
}

- (float)shadowSplitLambda {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        return pass->GetSplitLambda();
    }
    return 0.95f;
}

- (void)setShadowSplitLambda:(float)lambda {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        pass->SetSplitLambda(lambda);
    }
}

- (BOOL)shadowUpdateCascades {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        return pass->GetUpdateCascades();
    }
    return YES;
}

- (void)setShadowUpdateCascades:(BOOL)update {
    if (auto* pass = _application->GetRenderer()->GetPass<ShadowPass>()) {
        pass->SetUpdateCascades(update);
    }
}

#pragma mark - Deferred Pass

- (BOOL)deferredShowHeatmap {
    if (auto* pass = _application->GetRenderer()->GetPass<DeferredPass>()) {
        return pass->GetShowHeatmap();
    }
    return NO;
}

- (void)setDeferredShowHeatmap:(BOOL)show {
    if (auto* pass = _application->GetRenderer()->GetPass<DeferredPass>()) {
        pass->SetShowHeatmap(show);
    }
}

#pragma mark - Reflection Pass

- (NSInteger)reflectionTechnique {
    if (auto* pass = _application->GetRenderer()->GetPass<ReflectionPass>()) {
        return static_cast<NSInteger>(pass->GetTechnique());
    }
    return 0;
}

- (void)setReflectionTechnique:(NSInteger)technique {
    if (auto* pass = _application->GetRenderer()->GetPass<ReflectionPass>()) {
        pass->SetTechnique(static_cast<ReflectionTechnique>(technique));
    }
}

#pragma mark - GBuffer Pass

- (BOOL)gbufferFreezeICB {
    if (auto* pass = _application->GetRenderer()->GetPass<GBufferPass>()) {
        return pass->GetFreezeICB();
    }
    return NO;
}

- (void)setGbufferFreezeICB:(BOOL)freeze {
    if (auto* pass = _application->GetRenderer()->GetPass<GBufferPass>()) {
        pass->SetFreezeICB(freeze);
    }
}

#pragma mark - Tonemap Pass

- (float)tonemapGamma {
    if (auto* pass = _application->GetRenderer()->GetPass<TonemapPass>()) {
        return pass->GetGamma();
    }
    return 2.2f;
}

- (void)setTonemapGamma:(float)gamma {
    if (auto* pass = _application->GetRenderer()->GetPass<TonemapPass>()) {
        pass->SetGamma(gamma);
    }
}

#pragma mark - Debug Renderer

- (BOOL)debugRendererUseDepth {
    if (auto* pass = _application->GetRenderer()->GetPass<DebugRendererPass>()) {
        return pass->GetUseDepth();
    }
    return NO;
}

- (void)setDebugRendererUseDepth:(BOOL)useDepth {
    if (auto* pass = _application->GetRenderer()->GetPass<DebugRendererPass>()) {
        pass->SetUseDepth(useDepth);
    }
}

#pragma mark - Resize

- (void)resize:(CGSize)size {
    _application->OnResize((uint32_t)size.width, (uint32_t)size.height);
}

#pragma mark - Mouse Input

- (void)setMousePosition:(simd_float2)position {
#if !TARGET_OS_IPHONE
    if (_inputEnabled) {
        _application->GetInput().SetMousePosition(position);
    }
#endif
}

- (void)setRightMouseDown:(BOOL)down {
#if !TARGET_OS_IPHONE
    if (_inputEnabled) {
        _application->GetInput().SetRightMouseDown(down);
    }
#endif
}

#pragma mark - Input Control

- (BOOL)inputEnabled {
    return _inputEnabled;
}

- (void)setInputEnabled:(BOOL)enabled {
    _inputEnabled = enabled;
    // Update the application's input system
    _application->GetInput().SetEnabled(enabled);
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    _application->OnResize((uint32_t)size.width, (uint32_t)size.height);
}

- (void)drawInMTKView:(MTKView *)view {
    @autoreleasepool {
        CFTimeInterval currentTime = CACurrentMediaTime();
        float deltaTime = _lastFrameTime > 0.0 ? (float)(currentTime - _lastFrameTime) : 0.016f;
        _lastFrameTime = currentTime;
        
        // Update performance metrics
        _frameTime = deltaTime * 1000.0f; // Convert to milliseconds
        _fps = 1.0f / deltaTime;
        
        // Update application
        _application->OnUpdate(deltaTime);
        
        // Render
        id<CAMetalDrawable> drawable = view.currentDrawable;
        if (drawable) {
            _application->OnRender(drawable);
            
            // Present the drawable
            id<MTLCommandBuffer> presentCommandBuffer = [_commandQueue commandBuffer];
            [presentCommandBuffer presentDrawable:drawable];
            [presentCommandBuffer commit];
        }
    }
}

@end
