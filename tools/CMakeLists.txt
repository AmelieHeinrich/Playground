cmake_minimum_required(VERSION 3.20)

# Set output directory for tool binaries
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)

# Add subdirectories for each tool
add_subdirectory(src/gltfcompress)
