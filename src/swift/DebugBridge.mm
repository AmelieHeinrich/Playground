#import "DebugBridge.h"
#import <Metal/MTLCaptureManager.h>
#include "Core/Logger.h"

#import <map>
#import <string>
#import <vector>
#import <deque>

struct AllocationEntry {
    NSString* name;
    size_t bytes;
    ResourceType type;
    HeapType heapType;
};

struct DrawRecord {
    int vertexCount;
    int instanceCount;
    BOOL indexed;
};

struct DispatchRecord {
    MTLSize threadgroups;
    MTLSize threadsPerGroup;
};

struct EncoderRecord {
    NSString* name;
    EncoderType type;
    std::vector<DrawRecord> draws;
    std::vector<DispatchRecord> dispatches;
    int copies;
    int executeIndirects;
    int accelerationBuilds;
};

struct FrameRecord {
    std::vector<EncoderRecord> encoders;
    int totalDrawCalls;
    int totalDispatches;
    int totalCopies;
    int totalExecuteIndirects;
    int totalAccelerationBuilds;
    long long totalVertices;
    long long totalInstances;
};

@implementation DebugBridge {
    // Memory tracking
    std::map<std::string, AllocationEntry> _allocations;
    
    // Encoder tracking
    FrameRecord _currentFrame;
    FrameRecord _lastCompletedFrame;
    EncoderRecord* _currentEncoder;
    BOOL _inFrame;
    
    // Time-series metrics
    std::deque<double> _frameTimeHistory;
    std::deque<double> _cpuTimeHistory;
    std::deque<double> _gpuTimeHistory;
    std::deque<size_t> _memoryHistory;
}

+ (instancetype)shared {
    static DebugBridge* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DebugBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _maxHistorySize = 300;
        _inFrame = NO;
        _currentEncoder = nullptr;
        _currentFrame = {};
        _lastCompletedFrame = {};
    }
    return self;
}

#pragma mark - Memory Tracking

- (void)trackAllocation:(NSString*)name
                   size:(size_t)bytes
                   type:(ResourceType)type
               heapType:(HeapType)heapType {
    AllocationEntry entry;
    entry.name = name;
    entry.bytes = bytes;
    entry.type = type;
    entry.heapType = heapType;
    _allocations[name.UTF8String] = entry;
}

- (void)trackAllocation:(NSString*)name
               resource:(id<MTLResource>)resource {
    ResourceType type = ResourceTypeOther;
    HeapType heapType = HeapTypePrivate;
    
    if ([resource conformsToProtocol:@protocol(MTLBuffer)]) {
        type = ResourceTypeBuffer;
    } else if ([resource conformsToProtocol:@protocol(MTLTexture)]) {
        id<MTLTexture> tex = (id<MTLTexture>)resource;
        switch (tex.textureType) {
            case MTLTextureType2D: type = ResourceTypeTexture2D; break;
            case MTLTextureType3D: type = ResourceTypeTexture3D; break;
            case MTLTextureTypeCube: type = ResourceTypeCube; break;
            case MTLTextureType2DArray: type = ResourceTypeTextureArray; break;
            default: type = ResourceTypeOther; break;
        }
    }
    
    switch (resource.storageMode) {
        case MTLStorageModePrivate: heapType = HeapTypePrivate; break;
        case MTLStorageModeShared: heapType = HeapTypeShared; break;
        default: heapType = HeapTypePrivate; break;
    }
    
    [self trackAllocation:name size:resource.allocatedSize type:type heapType:heapType];
}

- (void)removeAllocation:(NSString*)name {
    _allocations.erase(name.UTF8String);
}

- (NSArray<NSDictionary*>*)allAllocations {
    NSMutableArray* result = [NSMutableArray array];
    
    for (const auto& pair : _allocations) {
        [result addObject:@{
            @"name": pair.second.name,
            @"bytes": @(pair.second.bytes),
            @"type": @(pair.second.type),
            @"heapType": @(pair.second.heapType)
        }];
    }
    
    // Sort by size descending
    [result sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [b[@"bytes"] compare:a[@"bytes"]];
    }];
    
    return result;
}

- (size_t)totalMemoryUsed {
    size_t total = 0;
    for (const auto& pair : _allocations) {
        total += pair.second.bytes;
    }
    return total;
}

- (NSDictionary<NSNumber*, NSNumber*>*)memoryByType {
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    
    for (const auto& pair : _allocations) {
        NSNumber* typeKey = @(pair.second.type);
        NSNumber* current = result[typeKey] ?: @0;
        result[typeKey] = @(current.unsignedLongLongValue + pair.second.bytes);
    }
    
    return result;
}

#pragma mark - Encoder/Command Tracking

- (void)beginFrame {
    _currentFrame = {};
    _inFrame = YES;
}

- (void)beginEncoder:(NSString*)name type:(EncoderType)type {
    if (!_inFrame) return;
    
    EncoderRecord encoder;
    encoder.name = name;
    encoder.type = type;
    encoder.copies = 0;
    encoder.executeIndirects = 0;
    encoder.accelerationBuilds = 0;
    _currentFrame.encoders.push_back(encoder);
    _currentEncoder = &_currentFrame.encoders.back();
}

- (void)recordDraw:(int)vertexCount
     instanceCount:(int)instances
           indexed:(BOOL)indexed {
    if (!_currentEncoder) return;
    
    DrawRecord draw;
    draw.vertexCount = vertexCount;
    draw.instanceCount = instances;
    draw.indexed = indexed;
    _currentEncoder->draws.push_back(draw);
}

- (void)recordDispatch:(MTLSize)threadgroups
       threadsPerGroup:(MTLSize)threads {
    if (!_currentEncoder) return;
    
    DispatchRecord dispatch;
    dispatch.threadgroups = threadgroups;
    dispatch.threadsPerGroup = threads;
    _currentEncoder->dispatches.push_back(dispatch);
}

- (void)recordCopy {
    if (!_currentEncoder) return;
    _currentEncoder->copies++;
}

- (void)recordExecuteIndirect {
    if (!_currentEncoder) return;
    _currentEncoder->executeIndirects++;
}

- (void)recordAccelerationStructureBuild {
    if (!_currentEncoder) return;
    _currentEncoder->accelerationBuilds++;
}

- (void)endEncoder {
    _currentEncoder = nullptr;
}

- (void)endFrame {
    if (!_inFrame) return;
    
    // Calculate totals
    _currentFrame.totalDrawCalls = 0;
    _currentFrame.totalDispatches = 0;
    _currentFrame.totalCopies = 0;
    _currentFrame.totalExecuteIndirects = 0;
    _currentFrame.totalAccelerationBuilds = 0;
    _currentFrame.totalVertices = 0;
    _currentFrame.totalInstances = 0;
    
    for (const auto& encoder : _currentFrame.encoders) {
        _currentFrame.totalDrawCalls += (int)encoder.draws.size();
        _currentFrame.totalDispatches += (int)encoder.dispatches.size();
        _currentFrame.totalCopies += encoder.copies;
        _currentFrame.totalExecuteIndirects += encoder.executeIndirects;
        _currentFrame.totalAccelerationBuilds += encoder.accelerationBuilds;
        
        for (const auto& draw : encoder.draws) {
            _currentFrame.totalVertices += draw.vertexCount;
            _currentFrame.totalInstances += draw.instanceCount;
        }
    }
    
    _lastCompletedFrame = _currentFrame;
    _inFrame = NO;
}

- (NSDictionary*)currentFrameHierarchy {
    const FrameRecord& frame = _inFrame ? _currentFrame : _lastCompletedFrame;
    
    NSMutableArray* encoders = [NSMutableArray array];
    
    for (const auto& encoder : frame.encoders) {
        NSMutableArray* draws = [NSMutableArray array];
        for (const auto& draw : encoder.draws) {
            [draws addObject:@{
                @"vertexCount": @(draw.vertexCount),
                @"instanceCount": @(draw.instanceCount),
                @"indexed": @(draw.indexed)
            }];
        }
        
        NSMutableArray* dispatches = [NSMutableArray array];
        for (const auto& dispatch : encoder.dispatches) {
            [dispatches addObject:@{
                @"threadgroupsX": @(dispatch.threadgroups.width),
                @"threadgroupsY": @(dispatch.threadgroups.height),
                @"threadgroupsZ": @(dispatch.threadgroups.depth),
                @"threadsPerGroupX": @(dispatch.threadsPerGroup.width),
                @"threadsPerGroupY": @(dispatch.threadsPerGroup.height),
                @"threadsPerGroupZ": @(dispatch.threadsPerGroup.depth)
            }];
        }
        
        [encoders addObject:@{
            @"name": encoder.name,
            @"type": @(encoder.type),
            @"draws": draws,
            @"dispatches": dispatches,
            @"copies": @(encoder.copies),
            @"executeIndirects": @(encoder.executeIndirects),
            @"accelerationBuilds": @(encoder.accelerationBuilds)
        }];
    }
    
    return @{
        @"encoders": encoders,
        @"totalDrawCalls": @(frame.totalDrawCalls),
        @"totalDispatches": @(frame.totalDispatches),
        @"totalCopies": @(frame.totalCopies),
        @"totalExecuteIndirects": @(frame.totalExecuteIndirects),
        @"totalAccelerationBuilds": @(frame.totalAccelerationBuilds),
        @"totalVertices": @(frame.totalVertices),
        @"totalInstances": @(frame.totalInstances)
    };
}

- (int)totalDrawCalls {
    return _lastCompletedFrame.totalDrawCalls;
}

- (int)totalDispatches {
    return _lastCompletedFrame.totalDispatches;
}

- (int)totalCopies {
    return _lastCompletedFrame.totalCopies;
}

- (int)totalExecuteIndirects {
    return _lastCompletedFrame.totalExecuteIndirects;
}

- (int)totalAccelerationBuilds {
    return _lastCompletedFrame.totalAccelerationBuilds;
}

- (int)totalEncoders {
    return (int)_lastCompletedFrame.encoders.size();
}

- (long long)totalVertices {
    return _lastCompletedFrame.totalVertices;
}

- (long long)totalInstances {
    return _lastCompletedFrame.totalInstances;
}

#pragma mark - Time-Series Metrics

- (void)pushFrameTime:(double)ms {
    _frameTimeHistory.push_back(ms);
    while (_frameTimeHistory.size() > _maxHistorySize) {
        _frameTimeHistory.pop_front();
    }
}

- (void)pushCPUTime:(double)ms {
    _cpuTimeHistory.push_back(ms);
    while (_cpuTimeHistory.size() > _maxHistorySize) {
        _cpuTimeHistory.pop_front();
    }
}

- (void)pushGPUTime:(double)ms {
    _gpuTimeHistory.push_back(ms);
    while (_gpuTimeHistory.size() > _maxHistorySize) {
        _gpuTimeHistory.pop_front();
    }
}

- (void)pushMemoryUsage:(size_t)bytes {
    _memoryHistory.push_back(bytes);
    while (_memoryHistory.size() > _maxHistorySize) {
        _memoryHistory.pop_front();
    }
}

- (NSArray<NSNumber*>*)frameTimeHistory:(int)count {
    return [self historyFromDeque:_frameTimeHistory count:count];
}

- (NSArray<NSNumber*>*)cpuTimeHistory:(int)count {
    return [self historyFromDeque:_cpuTimeHistory count:count];
}

- (NSArray<NSNumber*>*)gpuTimeHistory:(int)count {
    return [self historyFromDeque:_gpuTimeHistory count:count];
}

- (NSArray<NSNumber*>*)memoryHistory:(int)count {
    NSMutableArray* result = [NSMutableArray array];
    int start = std::max(0, (int)_memoryHistory.size() - count);
    for (int i = start; i < (int)_memoryHistory.size(); i++) {
        [result addObject:@(_memoryHistory[i])];
    }
    return result;
}

- (NSArray<NSNumber*>*)historyFromDeque:(const std::deque<double>&)deque count:(int)count {
    NSMutableArray* result = [NSMutableArray array];
    int start = std::max(0, (int)deque.size() - count);
    for (int i = start; i < (int)deque.size(); i++) {
        [result addObject:@(deque[i])];
    }
    return result;
}

- (double)averageFrameTime {
    if (_frameTimeHistory.empty()) return 0;
    double sum = 0;
    for (double v : _frameTimeHistory) sum += v;
    return sum / _frameTimeHistory.size();
}

- (double)averageCPUTime {
    if (_cpuTimeHistory.empty()) return 0;
    double sum = 0;
    for (double v : _cpuTimeHistory) sum += v;
    return sum / _cpuTimeHistory.size();
}

- (double)averageGPUTime {
    if (_gpuTimeHistory.empty()) return 0;
    double sum = 0;
    for (double v : _gpuTimeHistory) sum += v;
    return sum / _gpuTimeHistory.size();
}

- (double)currentFPS {
    double avgFrameTime = [self averageFrameTime];
    return avgFrameTime > 0 ? 1000.0 / avgFrameTime : 0;
}

- (double)minFrameTime {
    if (_frameTimeHistory.empty()) return 0;
    double minVal = _frameTimeHistory[0];
    for (double v : _frameTimeHistory) {
        if (v < minVal) minVal = v;
    }
    return minVal;
}

- (double)maxFrameTime {
    if (_frameTimeHistory.empty()) return 0;
    double maxVal = _frameTimeHistory[0];
    for (double v : _frameTimeHistory) {
        if (v > maxVal) maxVal = v;
    }
    return maxVal;
}

#pragma mark - GPU Capture

- (void)triggerGPUCapture {
    MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
    if ([captureManager supportsDestination:MTLCaptureDestinationDeveloperTools]) {
        MTLCaptureDescriptor* descriptor = [[MTLCaptureDescriptor alloc] init];
        descriptor.captureObject = MTLCreateSystemDefaultDevice();
        descriptor.destination = MTLCaptureDestinationDeveloperTools;
        
        NSError* error = nil;
        if (![captureManager startCaptureWithDescriptor:descriptor error:&error]) {
            LOG_ERROR_FMT("Failed to start GPU capture: %@", error);
        }
    }
}

- (BOOL)gpuCaptureAvailable {
    MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
    return [captureManager supportsDestination:MTLCaptureDestinationDeveloperTools];
}

@end
