#!/bin/bash

# Script to generate compile_commands.json for clangd

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

# Run CMake with compile commands export
echo "Generating compile_commands.json..."
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DCMAKE_BUILD_TYPE=Debug \
      "${PROJECT_DIR}"

# Copy compile_commands.json to project root for clangd
if [ -f "compile_commands.json" ]; then
    cp compile_commands.json "${PROJECT_DIR}/"
    echo "✓ compile_commands.json generated and copied to project root"
else
    echo "✗ Failed to generate compile_commands.json"
    exit 1
fi

echo "Done! You can now use clangd for code completion and analysis."
