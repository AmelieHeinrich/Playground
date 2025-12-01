#!/bin/bash

# Script to generate Xcode project for iOS

# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Project root is parent directory of scripts/
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Build directory for Xcode iOS
BUILD_DIR="${PROJECT_DIR}/build-xcode-ios"

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"

# Navigate to build directory
cd "${BUILD_DIR}"

# Run CMake with Xcode generator for iOS
echo "Generating Xcode project for iOS..."
cmake -G Xcode \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DCMAKE_IOS_INSTALL_COMBINED=YES \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
      -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="" \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      "${PROJECT_DIR}"

# Check if Xcode project was created
if [ -f "Playground.xcodeproj/project.pbxproj" ]; then
    echo "✓ Xcode iOS project generated at: ${BUILD_DIR}/Playground.xcodeproj"
    echo ""
    echo "To open the project in Xcode, run:"
    echo "  open ${BUILD_DIR}/Playground.xcodeproj"
    echo ""
    echo "Note: You'll need to set your Development Team in Xcode before building for a device."
    echo "      This can be done in Xcode under Signing & Capabilities."
else
    echo "✗ Failed to generate Xcode iOS project"
    exit 1
fi

echo "Done!"
