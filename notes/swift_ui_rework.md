# Metal Renderer Settings & Debug System Architecture

## Overview
Building a comprehensive settings and debug system for a Metal renderer that bridges Objective-C++ engine code with a SwiftUI interface. The system is divided into four separate bridges, each handling a specific concern.

## System Architecture

### 1. CVarRegistry (Settings/Console Variables)
**Purpose:** Manage runtime-configurable settings that control rendering behavior.

**Design:**
- Settings declared in C++/Obj-C++ code with direct pointer binding
- Hierarchical organization using dot notation (e.g., `RenderSettings.Shadows.Resolution`)
- SwiftUI dynamically generates UI from registry metadata
- Zero-overhead reads in render loop (direct pointer access)
- All on same thread, no synchronization needed

**Features:**
- Float settings (with min/max ranges)
- Int settings (with min/max ranges)
- Bool settings (toggles)
- Enum settings (dropdown with options)
- Color settings (simd_float4)

**Implementation approach:**
```objc
@interface CVarRegistry : NSObject

- (void)registerFloat:(NSString*)key 
              pointer:(float*)ptr 
                  min:(float)min 
                  max:(float)max 
          displayName:(NSString*)name;

- (void)registerInt:(NSString*)key 
            pointer:(int*)ptr 
                min:(int)min 
                max:(int)max 
        displayName:(NSString*)name;

- (void)registerBool:(NSString*)key 
             pointer:(bool*)ptr 
         displayName:(NSString*)name;

- (void)registerEnum:(NSString*)key 
             pointer:(int*)ptr 
             options:(NSArray<NSString*>*)options 
         displayName:(NSString*)name;

- (void)registerColor:(NSString*)key 
              pointer:(simd_float4*)ptr 
          displayName:(NSString*)name;

- (NSArray<NSDictionary*>*)allCVars; // For UI generation

@end
```

**Usage example:**
```cpp
float m_ShadowResolution = 2048.0f;
int m_MSAASamples = 4;
bool m_EnableVSync = true;

[cvarRegistry registerFloat:@"RenderSettings.Shadows.Resolution"
                    pointer:&m_ShadowResolution
                        min:512.0f
                        max:8192.0f
                displayName:@"Shadow Resolution"];
```

**Swift side:**
- Iterate through `allCVars()`
- Parse dot notation to build hierarchical UI (sections/groups)
- Generate appropriate controls based on type:
  - Float → Slider
  - Int → Stepper/Slider
  - Bool → Toggle
  - Enum → Picker
  - Color → ColorPicker
- Create Bindings that read/write through the pointers

### 2. ConsoleBridge (Logging)
**Purpose:** Stream log messages from C++/Obj-C++ to SwiftUI console view.

**Design:**
- C++ pushes log messages with severity levels
- Swift displays in scrollable console with filtering
- Optionally support command input for debug console

**Implementation approach:**
```objc
typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug,
    LogLevelInfo,
    LogLevelWarning,
    LogLevelError
};

@interface ConsoleBridge : NSObject

- (void)setLogCallback:(void(^)(NSString* message, LogLevel level))callback;
- (void)log:(NSString*)message level:(LogLevel)level;

// Optional: command execution
- (void)registerCommand:(NSString*)name 
               callback:(void(^)(NSArray<NSString*>* args))callback;
- (void)executeCommand:(NSString*)commandLine;

@end
```

**Swift features:**
- Searchable/filterable log view
- Color-coded by severity
- Auto-scroll option
- Copy/export logs
- Optional command input field

### 3. ActionsBridge (One-shot Actions)
**Purpose:** Trigger C++ functions from SwiftUI buttons/menu items.

**Design:**
- Register named actions with callbacks
- Swift can invoke from anywhere (toolbar, menu, keyboard shortcuts)
- Fire-and-forget, no state

**Implementation approach:**
```objc
@interface ActionsBridge : NSObject

- (void)registerAction:(NSString*)key 
              callback:(void(^)(void))callback 
           displayName:(NSString*)name 
              category:(NSString*)category; // For UI grouping

- (void)triggerAction:(NSString*)key;
- (NSArray<NSDictionary*>*)allActions;

@end
```

**Example actions:**
- Take screenshot
- Reload shaders
- Clear cache
- Rebuild shadow maps
- Toggle wireframe
- Capture Metal frame
- Reset camera

### 4. DebugBridge (Profiling & Visualization)
**Purpose:** Expose runtime performance data and resource information for profiling UI.

**Design:**
- Track allocations, encoder activity, and performance metrics
- Provide both current state and historical data for graphs
- Support detailed inspection of Metal resources

**Features:**

#### Memory Tracking
```objc
- (void)trackAllocation:(NSString*)name 
                   size:(size_t)bytes 
                   type:(MTLResourceType)type
               heapType:(MTLHeapType)heapType;

- (void)removeAllocation:(NSString*)name;

- (NSArray<NSDictionary*>*)allAllocations;
- (size_t)totalMemoryUsed;
- (NSDictionary*)memoryByType; // Breakdown by resource type
```

**Swift displays:**
- Table of all buffers/textures with sizes
- Color-coded by type
- Sortable by size/name/type
- Total memory usage
- Click for detailed info

#### Encoder/Command Tracking
```objc
typedef NS_ENUM(NSInteger, EncoderType) {
    EncoderTypeRender,
    EncoderTypeCompute,
    EncoderTypeBlit
};

- (void)beginFrame;
- (void)beginEncoder:(NSString*)name type:(EncoderType)type;
- (void)recordDraw:(int)vertexCount 
     instanceCount:(int)instances 
         indexType:(MTLIndexType)indexType;
- (void)recordDispatch:(MTLSize)threadgroups 
       threadsPerGroup:(MTLSize)threads;
- (void)endEncoder;
- (void)endFrame;

- (NSDictionary*)currentFrameHierarchy; // Nested structure
```

**Swift displays:**
- Hierarchical view: Frame → Encoder → Draws/Dispatches
- Draw call count per encoder
- Total vertices/instances
- RenderDoc/PIX-style visualization

#### Time-Series Metrics
```objc
- (void)pushFrameTime:(double)ms;
- (void)pushCPUTime:(double)ms;
- (void)pushGPUTime:(double)ms;
- (void)pushMemoryUsage:(size_t)bytes;

- (NSArray<NSNumber*>*)frameTimeHistory:(int)count; // Last N frames
- (NSArray<NSNumber*>*)cpuTimeHistory:(int)count;
- (NSArray<NSNumber*>*)gpuTimeHistory:(int)count;
- (NSArray<NSNumber*>*)memoryHistory:(int)count;

- (double)averageFrameTime;
- (double)currentFPS;
```

**Swift displays:**
- Real-time graphs (line charts)
- Rolling window (last 60/120/300 frames)
- Min/max/average overlays
- Configurable metrics to display

#### Texture Debug View
```objc
- (NSArray<NSDictionary*>*)allTextures; // Name, pointer, dims, format, mips

// Option 1: Convert to CGImage
- (CGImageRef)createCGImageFromTexture:(id<MTLTexture>)texture 
                              mipLevel:(NSUInteger)level
                                 slice:(NSUInteger)slice;

// Option 2: Get texture for MTKView rendering
- (id<MTLTexture>)getTexture:(NSString*)name;
```

**Swift displays:**
- Grid of texture thumbnails
- Click to inspect full resolution
- MTKView with:
  - Zoom/pan controls
  - Mip level selection
  - Array slice selection
  - Channel swizzling (R/G/B/A/RGB only)
  - Format/dimension info

**Additional features:**
- GPU capture trigger
- Export texture to file
- Histogram visualization
- Pixel inspector (hover to see RGBA values)

## Implementation Notes

### Why Objective-C Classes Instead of C API
- Entire project is Obj-C++, no need for C wrapper layer
- Better type safety with blocks instead of function pointers
- More idiomatic Objective-C code
- Easier Swift interop
- Less boilerplate

### Lifetime Management
- Settings pointers must remain valid for registry lifetime
- Store pointers to member variables in long-lived objects
- Avoid registering settings from temporary objects

### Thread Safety
- All bridges operate on same thread (main/render thread)
- No locking needed
- Swift UI updates trigger immediate pointer writes
- Render loop reads directly from pointers

### SwiftUI Integration
**CVarRegistry:**
```swift
ForEach(cvarRegistry.allCVars(), id: \.key) { cvar in
    switch cvar.type {
    case .float:
        VStack(alignment: .leading) {
            Text(cvar.displayName)
            Slider(value: Binding(
                get: { cvar.valuePtr.pointee },
                set: { cvar.valuePtr.pointee = $0 }
            ), in: cvar.min...cvar.max)
        }
    case .bool:
        Toggle(cvar.displayName, isOn: Binding(
            get: { cvar.valuePtr.pointee },
            set: { cvar.valuePtr.pointee = $0 }
        ))
    // ... other types
    }
}
```

**ActionsBridge:**
```swift
Button(action.displayName) {
    actionsBridge.triggerAction(action.key)
}
```

**DebugBridge:**
```swift
// Texture viewer using MTKView
struct MetalTextureView: NSViewRepresentable {
    let texture: MTLTexture
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = texture.device
        view.delegate = context.coordinator
        return view
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let texture: MTLTexture
        
        func draw(in view: MTKView) {
            // Blit texture to drawable
        }
    }
}
```

## Benefits of This Architecture

1. **Separation of Concerns:** Each bridge handles one specific domain
2. **Flexibility:** SwiftUI can compose UI however needed - sidebars, panels, overlays, menus
3. **Type Safety:** Direct pointer access, no serialization overhead
4. **Performance:** Zero-copy for settings reads, minimal overhead for debug tracking
5. **Extensibility:** Easy to add new setting types or debug views
6. **Developer Experience:** In-engine profiler eliminates context switching to Xcode

## Future Enhancements

- Serialize CVars to disk for persistence
- Remote debugging over network
- Comparison mode (before/after settings changes)
- Performance regression detection
- GPU shader profiling integration
- Memory leak detection
- Capture replay system
