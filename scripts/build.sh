#!/bin/bash

# Script to build the project

# Exit on error
set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Project root is parent directory of scripts/
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Build directory
BUILD_DIR="${PROJECT_DIR}/build"

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"

# Navigate to build directory
cd "${BUILD_DIR}"

# Configure with CMake if needed
if [ ! -f "CMakeCache.txt" ]; then
    echo "Configuring project..."
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          "${PROJECT_DIR}"
fi

# Build the project
echo "Building project..."
cmake --build . --config Release

# Check if build was successful
if [ -d "bin/Playground.app" ]; then
    echo "✓ Build successful!"
    echo "  Application bundle: ${BUILD_DIR}/bin/Playground.app"
    echo ""
    echo "To run the application:"
    echo "  open ${BUILD_DIR}/bin/Playground.app"
else
    echo "✗ Build failed"
    exit 1
fi

echo "Done!"
