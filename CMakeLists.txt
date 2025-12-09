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

# ============================================================================
# Third-party Libraries
# ============================================================================

# Add ImGui library
add_subdirectory(thirdparty/imgui)

# ============================================================================
# Tools
# ============================================================================

# Add tools subdirectory
add_subdirectory(tools)

# ============================================================================
# Main Executable Target
# ============================================================================

# Collect all source files from src/
file(GLOB_RECURSE SOURCES "src/*.cpp" "src/*.mm" "src/*.m" "src/*.c")

# Collect all shader files from assets/shaders/
file(GLOB_RECURSE SHADERS "assets/shaders/*.msl" "assets/shaders/*.metal")

# Collect all texture files from assets/textures/
file(GLOB_RECURSE TEXTURES "assets/textures/*")

# Collect all font files from assets/fonts/
file(GLOB_RECURSE FONTS "assets/fonts/*")

# Collect all model files from assets/models/
file(GLOB_RECURSE MODELS "assets/models/*")

# Create the executable as an application bundle (works for both macOS and iOS)
add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SOURCES} ${SHADERS} ${TEXTURES} ${FONTS} ${MODELS})

# Add src/ to include directories
target_include_directories(${PROJECT_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Enable ARC (Automatic Reference Counting) for Objective-C/Objective-C++ files
target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:OBJC>:-fobjc-arc>
)

# Link ImGui library
target_link_libraries(${PROJECT_NAME} PRIVATE imgui)

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
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "13.0"
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ""
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "amelieheinrich.${PROJECT_NAME}"
    )

    # Link iOS frameworks
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Foundation"
        "-framework UIKit"
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
        XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET "10.15"
    )

    # Link macOS frameworks
    target_link_libraries(${PROJECT_NAME} PRIVATE
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
