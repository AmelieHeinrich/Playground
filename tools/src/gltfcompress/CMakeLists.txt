cmake_minimum_required(VERSION 3.20)
project(gltfcompress)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Create executable
add_executable(gltfcompress main.mm tiny_gltf.mm)

# Include directory for tiny_gltf.h
target_include_directories(gltfcompress PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Enable ARC for Objective-C++ files
target_compile_options(gltfcompress PRIVATE
    $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
)

# Link Foundation framework on macOS
if(APPLE)
    target_link_libraries(gltfcompress PRIVATE
        "-framework Foundation"
    )
endif()

# Set output directory to tools/bin
set_target_properties(gltfcompress PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../bin"
)
