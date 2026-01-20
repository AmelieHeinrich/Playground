# Logger System

A simple C++ logger that bridges to the SwiftUI console system through `ConsoleBridge`.

## Features

- Four log levels: Debug, Info, Warning, Error
- Automatic integration with SwiftUI console view
- Printf-style formatting support
- Stream-style logging support
- Thread-safe logging through ConsoleBridge

## Basic Usage

### Include the Logger

```cpp
#include "Core/Logger.h"
```

### Simple String Logging

```cpp
// Log simple messages
LOG_DEBUG("Debugging information");
LOG_INFO("General information");
LOG_WARNING("Warning message");
LOG_ERROR("Error occurred");
```

### Formatted String Logging (printf-style)

```cpp
// Log with format strings (printf-style)
LOG_DEBUG_FMT("Loading file: %s", filename.c_str());
LOG_INFO_FMT("Initialized with %d items", count);
LOG_WARNING_FMT("Low memory: %zu bytes remaining", available);
LOG_ERROR_FMT("Failed to open file: %s (error: %d)", path.c_str(), errno);
```

### Stream-Style Logging

```cpp
// Stream-style logging (flushes at end of scope)
LOG_DEBUG_STREAM << "Loading texture: " << textureName << " size: " << width << "x" << height;
LOG_INFO_STREAM << "FPS: " << fps << " Frame time: " << frameTime << "ms";
```

### Using Logger Instance Methods

```cpp
// Access the singleton directly
Logger& logger = Logger::Get();

// Log with methods
logger.Debug("Debug message");
logger.Info("Info message");
logger.Warning("Warning message");
logger.Error("Error message");

// Formatted logging
logger.Debug("Value: %d", value);
logger.Info("Processing %s", name.c_str());
```

## Log Levels

| Level   | Purpose                                      | Macro          |
|---------|----------------------------------------------|----------------|
| Debug   | Detailed debugging information               | `LOG_DEBUG`    |
| Info    | General informational messages               | `LOG_INFO`     |
| Warning | Warning messages (non-critical issues)       | `LOG_WARNING`  |
| Error   | Error messages (critical issues)             | `LOG_ERROR`    |

## Integration with SwiftUI Console

All log messages are automatically sent to the SwiftUI console view through the `ConsoleBridge`. This means:

- Logs appear in the in-game console UI
- Logs are timestamped
- Logs maintain history (configurable in ConsoleBridge)
- Logs also appear in Xcode console via NSLog

## Examples

### Resource Loading

```cpp
void LoadTexture(const std::string& path) {
    LOG_INFO_FMT("Loading texture: %s", path.c_str());
    
    auto result = LoadFile(path);
    if (!result.success) {
        LOG_ERROR_FMT("Failed to load texture: %s - %s", path.c_str(), result.error.c_str());
        return;
    }
    
    LOG_DEBUG_FMT("Texture loaded successfully: %dx%d, %zu bytes", 
                  width, height, result.size);
}
```

### Performance Monitoring

```cpp
void UpdateFrame(float deltaTime) {
    if (deltaTime > 16.67f) {
        LOG_WARNING_FMT("Frame time high: %.2fms (target: 16.67ms)", deltaTime);
    }
    
    LOG_DEBUG_STREAM << "Frame: " << frameCount 
                     << " Time: " << deltaTime << "ms"
                     << " FPS: " << (1000.0f / deltaTime);
}
```

### Metal Device Initialization

```cpp
bool InitializeDevice() {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        LOG_ERROR("Failed to create Metal device: not supported on this system");
        return false;
    }
    
    LOG_INFO_FMT("Metal device created: %@", [device name]);
    LOG_DEBUG_FMT("Device supports family: %d", device.supportsFamily(...));
    return true;
}
```

## Implementation Details

- **Thread Safety**: Logging is thread-safe through ConsoleBridge's synchronization
- **Performance**: Minimal overhead; messages are formatted only when needed
- **Memory**: Log history is managed by ConsoleBridge (default: 1000 entries)
- **Objective-C Interop**: Uses `LogLevel` enum from ConsoleBridge.h

## Replacing NSLog

All `NSLog` calls in the codebase have been replaced with Logger calls:

```cpp
// Before:
NSLog(@"Failed to load: %s", path.c_str());

// After:
LOG_ERROR_FMT("Failed to load: %s", path.c_str());
```

This provides better integration with the UI and centralized log management.