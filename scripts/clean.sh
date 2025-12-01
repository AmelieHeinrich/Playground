#!/bin/bash

# Script to clean build artifacts

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Project root is parent directory of scripts/
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Navigate to project directory
cd "${PROJECT_DIR}"

echo "Cleaning build artifacts..."

# Remove build directories
if [ -d "build" ]; then
    echo "  Removing build/"
    rm -rf build
fi

if [ -d "build-xcode" ]; then
    echo "  Removing build-xcode/"
    rm -rf build-xcode
fi

if [ -d "build-xcode-ios" ]; then
    echo "  Removing build-xcode-ios/"
    rm -rf build-xcode-ios
fi

if [ -d "build-ios-simulator" ]; then
    echo "  Removing build-ios-simulator/"
    rm -rf build-ios-simulator
fi

# Remove compile_commands.json from root
if [ -f "compile_commands.json" ]; then
    echo "  Removing compile_commands.json"
    rm -f compile_commands.json
fi

# Remove CMake cache files that might be in the root
if [ -f "CMakeCache.txt" ]; then
    echo "  Removing CMakeCache.txt"
    rm -f CMakeCache.txt
fi

if [ -d "CMakeFiles" ]; then
    echo "  Removing CMakeFiles/"
    rm -rf CMakeFiles
fi

echo "✓ Clean complete!"
echo ""
echo "All build artifacts have been removed."
echo "Run ./scripts/build.sh or ./scripts/generate_xcode.sh to rebuild."
