cmake_minimum_required(VERSION 3.20)
project(Playground VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Export compile commands for clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

# Collect all source files from src/
file(GLOB_RECURSE SOURCES "src/*.cpp" "src/*.mm" "src/*.m" "src/*.c")

# Create the executable as an application bundle (works for both macOS and iOS)
add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SOURCES})

# Platform-specific bundle properties
if(IOS)
    # iOS-specific settings
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJECT_NAME}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.${PROJECT_NAME}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info-iOS.plist.in"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"  # iPhone and iPad
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "13.0"
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ""
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.example.${PROJECT_NAME}"
    )

    # Link iOS frameworks
    target_link_libraries(${PROJECT_NAME}
        "-framework Foundation"
        "-framework UIKit"
        "-framework Metal"
        "-framework MetalKit"
        "-framework QuartzCore"
    )

elseif(MACOS)
    # macOS-specific settings
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJECT_NAME}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.${PROJECT_NAME}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info-macOS.plist.in"
        XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET "10.15"
    )

    # Link macOS frameworks
    target_link_libraries(${PROJECT_NAME}
        "-framework Foundation"
        "-framework Cocoa"
        "-framework Metal"
        "-framework MetalKit"
        "-framework QuartzCore"
    )
endif()

# Set output directory
set_target_properties(${PROJECT_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Installation rules
install(TARGETS ${PROJECT_NAME}
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
