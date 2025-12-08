cmake_minimum_required(VERSION 3.20)
project(imgui)

# Detect platform
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(IOS TRUE)
    set(MACOS FALSE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(IOS FALSE)
    set(MACOS TRUE)
else()
    set(IOS FALSE)
    set(MACOS FALSE)
endif()

# ImGui core source files
set(IMGUI_SOURCES
    imgui.cpp
    imgui_demo.cpp
    imgui_draw.cpp
    imgui_tables.cpp
    imgui_widgets.cpp
)

# ImGui Metal backend
set(IMGUI_BACKEND_SOURCES
    imgui_impl_metal.mm
)

# Platform-specific ImGui backend
if(MACOS)
    list(APPEND IMGUI_BACKEND_SOURCES imgui_impl_osx.mm)
endif()

# Create ImGui static library
add_library(imgui STATIC ${IMGUI_SOURCES} ${IMGUI_BACKEND_SOURCES})

# ImGui include directories
target_include_directories(imgui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Link frameworks needed by ImGui
if(IOS)
    target_link_libraries(imgui PUBLIC
        "-framework Foundation"
        "-framework UIKit"
        "-framework Metal"
        "-framework MetalKit"
        "-framework QuartzCore"
    )
elseif(MACOS)
    target_link_libraries(imgui PUBLIC
        "-framework Foundation"
        "-framework Cocoa"
        "-framework Metal"
        "-framework MetalKit"
        "-framework QuartzCore"
        "-framework GameController"
    )
endif()

# Disable warnings for ImGui
if(MSVC)
    target_compile_options(imgui PRIVATE /W0)
else()
    target_compile_options(imgui PRIVATE -w)
endif()
