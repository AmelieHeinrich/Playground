#!/bin/bash

# Script to build the project for iOS Simulator

# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Project root is parent directory of scripts/
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Build directory
BUILD_DIR="${PROJECT_DIR}/build-ios-simulator"

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"

# Navigate to build directory
cd "${BUILD_DIR}"

# Configure with CMake if needed
if [ ! -f "CMakeCache.txt" ]; then
    echo "Configuring project for iOS Simulator..."
    cmake -G Xcode \
          -DCMAKE_SYSTEM_NAME=iOS \
          -DCMAKE_OSX_SYSROOT=iphonesimulator \
          -DCMAKE_OSX_ARCHITECTURES=x86_64\;arm64 \
          -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
          -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          "${PROJECT_DIR}"
fi

# Build the project for simulator
echo "Building project for iOS Simulator..."
cmake --build . --config Release -- -sdk iphonesimulator

# Check if build was successful
if [ -d "bin/Release/Playground.app" ]; then
    echo "✓ Build successful!"
    echo "  Application bundle: ${BUILD_DIR}/bin/Release/Playground.app"
    echo ""
    echo "To run in simulator, use Xcode or:"
    echo "  xcrun simctl install booted ${BUILD_DIR}/bin/Release/Playground.app"
    echo "  xcrun simctl launch booted com.example.Playground"
else
    echo "✗ Build failed"
    exit 1
fi

echo "Done!"
