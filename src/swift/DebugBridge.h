#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EncoderType) {
    EncoderTypeRender,
    EncoderTypeCompute,
    EncoderTypeBlit,
    EncoderTypeAcceleration
};

typedef NS_ENUM(NSInteger, ResourceType) {
    ResourceTypeBuffer,
    ResourceTypeTexture2D,
    ResourceTypeTexture3D,
    ResourceTypeCube,
    ResourceTypeTextureArray,
    ResourceTypeHeap,
    ResourceTypeAccelerationStructure,
    ResourceTypeOther
};

typedef NS_ENUM(NSInteger, HeapType) {
    HeapTypePrivate,
    HeapTypeShared,
    HeapTypeManaged
};

@interface DebugBridge : NSObject

+ (instancetype)shared;

#pragma mark - Memory Tracking

- (void)trackAllocation:(NSString*)name
                   size:(size_t)bytes
                   type:(ResourceType)type
               heapType:(HeapType)heapType;

- (void)trackAllocation:(NSString*)name
               resource:(id<MTLResource>)resource;

- (void)removeAllocation:(NSString*)name;

- (NSArray<NSDictionary*>*)allAllocations;
- (size_t)totalMemoryUsed;
- (NSDictionary<NSNumber*, NSNumber*>*)memoryByType; // ResourceType -> bytes

#pragma mark - Encoder/Command Tracking

- (void)beginFrame;
- (void)beginEncoder:(NSString*)name type:(EncoderType)type;
- (void)recordDraw:(int)vertexCount
     instanceCount:(int)instances
           indexed:(BOOL)indexed;
- (void)recordDispatch:(MTLSize)threadgroups
       threadsPerGroup:(MTLSize)threads;
- (void)recordCopy;
- (void)recordExecuteIndirect;
- (void)recordAccelerationStructureBuild;
- (void)endEncoder;
- (void)endFrame;

// Returns the hierarchy of the current (or last completed) frame
// Structure: { encoders: [{ name, type, draws: [...], dispatches: [...] }] }
- (NSDictionary*)currentFrameHierarchy;

// Frame statistics
@property (nonatomic, readonly) int totalDrawCalls;
@property (nonatomic, readonly) int totalDispatches;
@property (nonatomic, readonly) int totalCopies;
@property (nonatomic, readonly) int totalExecuteIndirects;
@property (nonatomic, readonly) int totalAccelerationBuilds;
@property (nonatomic, readonly) int totalEncoders;
@property (nonatomic, readonly) long long totalVertices;
@property (nonatomic, readonly) long long totalInstances;

#pragma mark - Time-Series Metrics

- (void)pushFrameTime:(double)ms;
- (void)pushCPUTime:(double)ms;
- (void)pushGPUTime:(double)ms;
- (void)pushMemoryUsage:(size_t)bytes;

// Get history (last N samples)
- (NSArray<NSNumber*>*)frameTimeHistory:(int)count;
- (NSArray<NSNumber*>*)cpuTimeHistory:(int)count;
- (NSArray<NSNumber*>*)gpuTimeHistory:(int)count;
- (NSArray<NSNumber*>*)memoryHistory:(int)count;

// Aggregates
- (double)averageFrameTime;
- (double)averageCPUTime;
- (double)averageGPUTime;
- (double)currentFPS;
- (double)minFrameTime;
- (double)maxFrameTime;

// History configuration
@property (nonatomic) NSUInteger maxHistorySize; // Default: 300

#pragma mark - GPU Capture

// Trigger a GPU capture (requires Xcode GPU Frame Capture enabled)
- (void)triggerGPUCapture;
@property (nonatomic, readonly) BOOL gpuCaptureAvailable;

@end

NS_ASSUME_NONNULL_END
