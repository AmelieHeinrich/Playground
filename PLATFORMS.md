# Platform Support

This project supports building for both macOS and iOS using CMake with automatic platform detection.

## Supported Platforms

- **macOS** 10.15 (Catalina) and later
- **iOS** 13.0 and later (Device and Simulator)

## Platform Detection

The CMakeLists.txt automatically detects the target platform based on `CMAKE_SYSTEM_NAME`:

- `Darwin` → macOS build
- `iOS` → iOS build

## Platform Differences

### Frameworks

| Platform | Frameworks Linked |
|----------|------------------|
| macOS    | Foundation, Cocoa |
| iOS      | Foundation, UIKit |

### Bundle Structure

**macOS App Bundle:**
```
Playground.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── Playground (executable)
    └── Resources/
```

**iOS App Bundle:**
```
Playground.app/
├── Info.plist
├── PkgInfo
├── Playground (executable)
└── _CodeSignature/
```

### Architectures

| Platform | Architectures |
|----------|--------------|
| macOS    | x86_64, arm64 (Apple Silicon) |
| iOS Simulator | x86_64, arm64 |
| iOS Device | arm64 |

## Build Scripts Reference

| Script | Platform | Output |
|--------|----------|--------|
| `build.sh` | macOS | `build/bin/Playground.app` |
| `build_ios_simulator.sh` | iOS Simulator | `build-ios-simulator/bin/Release/Playground.app` |
| `generate_xcode.sh` | macOS | `build-xcode/Playground.xcodeproj` |
| `generate_xcode_ios.sh` | iOS | `build-xcode-ios/Playground.xcodeproj` |

## Adding Platform-Specific Code

You can use conditional compilation to handle platform differences:

```objective-c++
#if TARGET_OS_IPHONE
    // iOS-specific code
    #import <UIKit/UIKit.h>
    UIViewController *vc = [[UIViewController alloc] init];
#else
    // macOS-specific code
    #import <Cocoa/Cocoa.h>
    NSViewController *vc = [[NSViewController alloc] init];
#endif
```

Or use macros in CMakeLists.txt:

```cmake
if(IOS)
    target_compile_definitions(${PROJECT_NAME} PRIVATE BUILD_FOR_IOS=1)
elseif(MACOS)
    target_compile_definitions(${PROJECT_NAME} PRIVATE BUILD_FOR_MACOS=1)
endif()
```

## Deployment

### macOS

macOS apps can be:
- Distributed as `.app` bundles
- Packaged in `.dmg` disk images
- Notarized for distribution outside the Mac App Store
- Submitted to the Mac App Store

### iOS

iOS apps require:
- Apple Developer Program membership
- Code signing with a valid certificate
- Provisioning profile for device testing
- App Store submission for distribution

## Code Signing

### macOS

Code signing is optional for development but required for distribution:

```bash
codesign --force --deep --sign "Developer ID Application: Your Name" \
         build/bin/Playground.app
```

### iOS

Code signing is always required. Set your Development Team in CMakeLists.txt:

```cmake
XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "YOUR_TEAM_ID"
```

Or configure it in Xcode after generating the project.

## Testing

### macOS

Run directly:
```bash
open build/bin/Playground.app
```

Or from command line:
```bash
build/bin/Playground.app/Contents/MacOS/Playground
```

### iOS Simulator

List available simulators:
```bash
xcrun simctl list devices
```

Boot a simulator:
```bash
xcrun simctl boot "iPhone 15 Pro"
```

Install and run:
```bash
xcrun simctl install booted build-ios-simulator/bin/Release/Playground.app
xcrun simctl launch booted com.example.Playground
```

### iOS Device

Build must be done through Xcode with proper code signing:

1. Open `build-xcode-ios/Playground.xcodeproj`
2. Select your Development Team
3. Connect your device
4. Select your device as the build target
5. Build and run (⌘R)

## Verified Working

- ✅ macOS build links with Cocoa framework
- ✅ iOS build links with UIKit framework
- ✅ iOS Simulator builds for both arm64 and x86_64
- ✅ Proper app bundle structure for each platform
- ✅ Platform detection works automatically
- ✅ Xcode project generation for both platforms