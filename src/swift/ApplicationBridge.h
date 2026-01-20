#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationBridge : NSObject <MTKViewDelegate>

// Initialization
- (nullable instancetype)initWithDevice:(id<MTLDevice>)device;

// Device access
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;

// Performance metrics (read-only, updated each frame)
@property (nonatomic, readonly) float fps;
@property (nonatomic, readonly) float frameTime;

// Resolution info (read-only)
@property (nonatomic, readonly) NSUInteger outputWidth;
@property (nonatomic, readonly) NSUInteger outputHeight;
@property (nonatomic, readonly) NSUInteger renderWidth;
@property (nonatomic, readonly) NSUInteger renderHeight;

// Render scale (0.25, 0.5, 0.75, 1.0)
@property (nonatomic) float renderScale;

// Point lights
@property (nonatomic, readonly) NSInteger pointLightCount;
- (void)addRandomLights:(NSInteger)count;
- (void)clearAllLights;

// Directional light
@property (nonatomic) BOOL directionalLightEnabled;
@property (nonatomic) simd_float3 directionalLightDirection;
@property (nonatomic) simd_float3 directionalLightColor;
@property (nonatomic) float directionalLightIntensity;

// Shadow pass settings
// Technique: 0=None, 1=Raytraced Hard, 2=CSM
@property (nonatomic) NSInteger shadowTechnique;
// Resolution: 0=Low(512), 1=Medium(1024), 2=High(2048), 3=Ultra(4096)
@property (nonatomic) NSInteger shadowResolution;
@property (nonatomic) float shadowSplitLambda;
@property (nonatomic) BOOL shadowUpdateCascades;

// Deferred pass settings
@property (nonatomic) BOOL deferredShowHeatmap;

// Reflection pass settings
// Technique: 0=None, 1=SS Mirror, 2=Hybrid Mirror, 3=SS Glossy, 4=Hybrid Glossy
@property (nonatomic) NSInteger reflectionTechnique;

// GBuffer pass settings
@property (nonatomic) BOOL gbufferFreezeICB;

// Tonemap pass settings
@property (nonatomic) float tonemapGamma;

// Debug renderer settings
@property (nonatomic) BOOL debugRendererUseDepth;

// Resize handling
- (void)resize:(CGSize)size;

// Mouse input handling
- (void)setMousePosition:(simd_float2)position;
- (void)setRightMouseDown:(BOOL)down;

@end

NS_ASSUME_NONNULL_END
