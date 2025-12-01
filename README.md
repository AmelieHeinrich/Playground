# Playground

A cross-platform graphics playground using Metal, exploring raytracing, GPU driven rendering, and a bit of ML.

Supports both macOS and iOS platforms.

## Project Structure

```
Playground/
├── CMakeLists.txt              # CMake build configuration
├── Info.plist.in               # App bundle info template
├── .gitignore                  # Git ignore patterns
├── README.md                   # This file
├── src/                        # Source files directory
│   └── main.mm
└── scripts/                    # Build scripts
    ├── build.sh                # Build for macOS
    ├── build_ios_simulator.sh  # Build for iOS Simulator
    ├── clean.sh                # Clean all build artifacts
    ├── generate_compile_commands.sh # Generate compile_commands.json for clangd
    ├── generate_xcode.sh       # Generate Xcode project for macOS
    └── generate_xcode_ios.sh   # Generate Xcode project for iOS
```

## Prerequisites

- CMake 3.20 or higher
- Xcode Command Line Tools
- Xcode (for iOS development and IDE features)
- macOS 10.15+ (for macOS builds)
- iOS 13.0+ (for iOS builds)

## Build Scripts

### macOS Development

#### 1. Building for macOS

To build the macOS application bundle:

```bash
./scripts/build.sh
```

This will:
- Create a `build/` directory
- Configure the project with CMake
- Build the project in Release mode
- Generate `Playground.app` in `build/bin/`

To run the built application:

```bash
open build/bin/Playground.app
```

#### 2. Generating Xcode Project for macOS

To develop using Xcode IDE:

```bash
./scripts/generate_xcode.sh
```

This will:
- Create a `build-xcode/` directory
- Generate `Playground.xcodeproj` for macOS

To open the project in Xcode:

```bash
open build-xcode/Playground.xcodeproj
```

### iOS Development

#### 1. Building for iOS Simulator

To build for the iOS Simulator:

```bash
./scripts/build_ios_simulator.sh
```

This will:
- Create a `build-ios-simulator/` directory
- Configure the project for iOS Simulator (arm64 and x86_64)
- Build the project in Release mode
- Generate `Playground.app` for simulator

To run in simulator:

```bash
# Install to booted simulator
xcrun simctl install booted build-ios-simulator/Release-iphonesimulator/Playground.app

# Launch the app
xcrun simctl launch booted com.example.Playground
```

#### 2. Generating Xcode Project for iOS

To develop iOS apps using Xcode IDE:

```bash
./scripts/generate_xcode_ios.sh
```

This will:
- Create a `build-xcode-ios/` directory
- Generate `Playground.xcodeproj` configured for iOS

To open the project in Xcode:

```bash
open build-xcode-ios/Playground.xcodeproj
```

**Important:** Before building for a physical device, you need to:
1. Open the project in Xcode
2. Select the Playground target
3. Go to "Signing & Capabilities"
4. Set your Development Team

### Code Completion & LSP

#### Generating compile_commands.json for clangd

For LSP support in editors like VSCode, Neovim, etc.:

```bash
./scripts/generate_compile_commands.sh
```

This will:
- Generate `compile_commands.json` in the build directory
- Copy it to the project root for clangd to find
- Enable code completion, go-to-definition, and other LSP features

### Cleaning Build Artifacts

To remove all build artifacts and start fresh:

```bash
./scripts/clean.sh
```

This will remove:
- `build/` directory (macOS build)
- `build-xcode/` directory (macOS Xcode project)
- `build-xcode-ios/` directory (iOS Xcode project)
- `build-ios-simulator/` directory (iOS Simulator build)
- `compile_commands.json` from project root
- Any stray CMake cache files

## Manual CMake Usage

### macOS

```bash
# Configure
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..

# Build
cmake --build . --config Release

# Run
open bin/Playground.app
```

For Xcode:

```bash
# Configure
mkdir build-xcode && cd build-xcode
cmake -G Xcode ..

# Open in Xcode
open Playground.xcodeproj
```

### iOS Simulator

```bash
# Configure
mkdir build-ios-simulator && cd build-ios-simulator
cmake -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_SYSROOT=iphonesimulator \
      -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
      ..

# Build
cmake --build . --config Release -- -sdk iphonesimulator
```

### iOS Device

```bash
# Configure
mkdir build-ios-device && cd build-ios-device
cmake -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_SYSROOT=iphoneos \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
      ..

# Build (requires code signing setup)
cmake --build . --config Release -- -sdk iphoneos
```

## Adding Source Files

Simply add your `.cpp`, `.mm`, `.m`, or `.c` files to the `src/` directory. CMake will automatically detect and compile them.

## Platform Detection

The CMakeLists.txt automatically detects the target platform:

- **macOS**: Links Foundation and Cocoa frameworks
- **iOS**: Links Foundation and UIKit frameworks

The same source code can be built for both platforms by using the appropriate build script.

## Customization

### Changing the Bundle Identifier

Edit `CMakeLists.txt` and modify:

```cmake
MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.${PROJECT_NAME}"
```

### Setting Your Development Team (iOS)

For iOS device builds, edit `CMakeLists.txt` and set:

```cmake
XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "YOUR_TEAM_ID"
```

Or configure it in Xcode after generating the project.

### Adding More Frameworks

Edit `CMakeLists.txt` and add to the appropriate `target_link_libraries` section:

**For macOS:**
```cmake
target_link_libraries(${PROJECT_NAME}
    "-framework Foundation"
    "-framework Cocoa"
    "-framework Metal"
    "-framework MetalKit"
)
```

**For iOS:**
```cmake
target_link_libraries(${PROJECT_NAME}
    "-framework Foundation"
    "-framework UIKit"
    "-framework Metal"
    "-framework MetalKit"
)
```

### Modifying Info.plist

Edit `Info.plist.in` to add or change bundle properties. Common additions:

- Camera usage: `NSCameraUsageDescription`
- Photo library: `NSPhotoLibraryUsageDescription`
- Location: `NSLocationWhenInUseUsageDescription`
- Required device capabilities: `UIRequiredDeviceCapabilities`

## Deployment Targets

- **macOS**: 10.15 (Catalina) and later
- **iOS**: 13.0 and later

These can be adjusted in `CMakeLists.txt`:

```cmake
# For macOS
XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET "10.15"

# For iOS
XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "13.0"
```

## Troubleshooting

### Build Issues

If you encounter build issues, try cleaning and rebuilding:

```bash
./scripts/clean.sh
./scripts/build.sh  # or build_ios_simulator.sh
```

### Code Signing Errors (iOS)

If you get code signing errors when building for iOS:

1. Open the Xcode project: `open build-xcode-ios/Playground.xcodeproj`
2. Select the Playground target
3. Go to "Signing & Capabilities"
4. Select your Team from the dropdown
5. Build from Xcode or command line

### Simulator Not Found

List available simulators:

```bash
xcrun simctl list devices
```

Boot a specific simulator:

```bash
xcrun simctl boot "iPhone 15 Pro"
```

## License

Copyright © 2024. All rights reserved.