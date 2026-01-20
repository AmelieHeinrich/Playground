cmake_minimum_required(VERSION 3.20)
project(Playground VERSION 1.0.0 LANGUAGES C CXX Swift)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Swift settings
set(CMAKE_Swift_LANGUAGE_VERSION 5)

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

# ============================================================================
# Third-party Libraries
# ============================================================================

# ImGui removed - using SwiftUI now
# add_subdirectory(thirdparty/imgui)

# Add libktx library
# Configure libktx options before adding subdirectory
set(LIBKTX_VERSION_FULL ON CACHE BOOL "" FORCE)
set(LIBKTX_VERSION_READ_ONLY OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(KTX_FEATURE_TOOLS OFF CACHE BOOL "" FORCE)
set(KTX_FEATURE_LOADTEST_APPS OFF CACHE BOOL "" FORCE)
set(KTX_FEATURE_DOC OFF CACHE BOOL "" FORCE)
set(KTX_FEATURE_TESTS OFF CACHE BOOL "" FORCE)
set(BASISU_SUPPORT_OPENCL OFF CACHE BOOL "" FORCE)

# Disable Vulkan upload on iOS/macOS (Metal is used instead)
if(IOS OR MACOS)
    set(LIBKTX_FEATURE_VK_UPLOAD OFF CACHE BOOL "" FORCE)
else()
    set(LIBKTX_FEATURE_VK_UPLOAD ON CACHE BOOL "" FORCE)
endif()

# Override install() command to no-op for libktx on iOS to avoid FRAMEWORK error
if(IOS)
    macro(install)
        # No-op to skip install commands in libktx on iOS
    endmacro()
endif()

add_subdirectory(thirdparty/libktx/lib)

# ============================================================================
# Tools
# ============================================================================

# Add tools subdirectory
add_subdirectory(tools)

# ============================================================================
# Main Executable Target
# ============================================================================

# Collect all source files from src/ (excluding old app_delegate and main for SwiftUI build)
file(GLOB_RECURSE SOURCES "src/*.cpp" "src/*.mm" "src/*.m" "src/*.c")

# Remove old entry points (SwiftUI has its own entry point)
list(FILTER SOURCES EXCLUDE REGEX ".*AppDelegate\\.mm$")
list(FILTER SOURCES EXCLUDE REGEX ".*Main\\.mm$")

# Collect all header files from src/
file(GLOB_RECURSE HEADERS "src/*.h")

# Collect Swift source files
file(GLOB_RECURSE SWIFT_SOURCES "src/Swift/*.swift")

# Collect all shader files from assets/shaders/ (excluding common subdirectory)
file(GLOB SHADERS "assets/shaders/*.metal")

# Collect shader header files for Xcode organization
file(GLOB SHADER_HEADERS "assets/shaders/common/*.h")

# Collect all texture files from assets/textures/
file(GLOB_RECURSE TEXTURES "assets/textures/*")

# Collect all font files from assets/fonts/
file(GLOB_RECURSE FONTS "assets/fonts/*")

# Collect all model files from assets/models/
file(GLOB_RECURSE MODELS "assets/models/*")

# Collect all model files from assets/models/
file(GLOB_RECURSE SKIES "assets/skies/*")

set_source_files_properties(
    ${CMAKE_SOURCE_DIR}/raw_assets/AppAssets.xcassets
    PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources
)

set_source_files_properties(${SHADERS}
    PROPERTIES
    LANGUAGE METAL
    XCODE_EXPLICIT_FILE_TYPE sourcecode.metal
    COMPILE_FLAGS "-std=metal3.0"
)

# Add Metal shader compilation flags for debug mode
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set_source_files_properties(${SHADERS}
        PROPERTIES
        COMPILE_FLAGS "-std=metal3.0 -frecord-sources -gline-tables-only"
    )
endif()

# Create the executable as an application bundle (works for both macOS and iOS)
add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SOURCES} ${HEADERS} ${SWIFT_SOURCES} ${SHADERS} ${SHADER_HEADERS} ${CMAKE_SOURCE_DIR}/raw_assets/AppAssets.xcassets)

if (IOS)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        XCODE_ATTRIBUTE_MTL_PREPROCESSOR_DEFINITIONS
        "IOS=1"
    )
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    XCODE_ATTRIBUTE_MTL_LANGUAGE_REVISION
    "Metal30"
)

# Swift/Objective-C bridging header
set_target_properties(${PROJECT_NAME} PROPERTIES
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER
    "${CMAKE_CURRENT_SOURCE_DIR}/src/Swift/Playground-Bridging-Header.h"
    XCODE_ATTRIBUTE_DEFINES_MODULE YES
    XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
)

# Source group for Xcode
source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR}/src FILES ${SOURCES} ${HEADERS} ${SWIFT_SOURCES})
source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR}/assets FILES ${SHADERS} ${SHADER_HEADERS})

# Add src/ to include directories
target_include_directories(${PROJECT_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Enable ARC (Automatic Reference Counting) for Objective-C/Objective-C++ files
target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:OBJC>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:C>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:CXX>:-fobjc-arc>
)

# Link libktx library (ImGui removed - using SwiftUI now)
target_link_libraries(${PROJECT_NAME} PRIVATE ktx)

# Add libktx include directories
target_include_directories(${PROJECT_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/libktx/lib/include"
)

# Define KHRONOS_STATIC when using static libktx
target_compile_definitions(${PROJECT_NAME} PRIVATE KHRONOS_STATIC)

# Mark shader files as resources
set_source_files_properties(${SHADERS} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources/shaders
)

# Mark texture files as resources
set_source_files_properties(${TEXTURES} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources/textures
)

# Mark font files as resources
set_source_files_properties(${FONTS} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources/fonts
)

# Mark model files as resources
set_source_files_properties(${MODELS} PROPERTIES
    MACOSX_PACKAGE_LOCATION Resources/models
)

# Copy asset subdirectories into the app bundle
# iOS: files go directly in the app bundle
# macOS: files go in Contents/Resources
if(IOS)
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/shaders"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/shaders"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/textures"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/textures"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/fonts"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/fonts"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/models"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/models"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/skies"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/skies"
        COMMENT "Copying asset subdirectories to iOS app bundle"
    )
else()
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/shaders"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/shaders"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/textures"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/textures"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/fonts"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/fonts"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/skies"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/skies"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/models"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>/../Resources/models"
        COMMENT "Copying asset subdirectories to macOS app bundle"
    )
endif()

# Platform-specific bundle properties
if(IOS)
    # iOS-specific settings
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJECT_NAME}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_GUI_IDENTIFIER "amelieheinrich.${PROJECT_NAME}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info-iOS.plist.in"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"  # iPhone and iPad
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "17.0"  # Required for @Observable
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ""
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "amelieheinrich.${PROJECT_NAME}"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon iOS"
    )

    # Link iOS frameworks
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Foundation"
        "-framework UIKit"
        "-framework SwiftUI"
        "-framework Metal"
        "-framework MetalKit"
        "-framework QuartzCore"
        "-framework GameController"
    )

elseif(MACOS)
    # macOS-specific settings
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJECT_NAME}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_GUI_IDENTIFIER "amelieheinrich.${PROJECT_NAME}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info-macOS.plist.in"
        XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET "14.0"  # Required for @Observable
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon macOS"
    )

    # Link macOS frameworks
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Foundation"
        "-framework Cocoa"
        "-framework SwiftUI"
        "-framework Metal"
        "-framework MetalKit"
        "-framework QuartzCore"
        "-framework GameController"
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
