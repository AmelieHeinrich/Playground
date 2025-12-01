#!/bin/bash

# Script to generate Xcode project

# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Project root is parent directory of scripts/
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Build directory for Xcode
BUILD_DIR="${PROJECT_DIR}/build-xcode"

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"

# Navigate to build directory
cd "${BUILD_DIR}"

# Run CMake with Xcode generator
echo "Generating Xcode project..."
cmake -G Xcode \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      "${PROJECT_DIR}"

# Check if Xcode project was created
if [ -f "Playground.xcodeproj/project.pbxproj" ]; then
    echo "✓ Xcode project generated at: ${BUILD_DIR}/Playground.xcodeproj"
    echo ""
    echo "To open the project in Xcode, run:"
    echo "  open ${BUILD_DIR}/Playground.xcodeproj"
else
    echo "✗ Failed to generate Xcode project"
    exit 1
fi

echo "Done!"
