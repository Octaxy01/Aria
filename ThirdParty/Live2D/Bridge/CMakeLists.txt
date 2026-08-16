cmake_minimum_required(VERSION 3.16)

# Build Live2D Bridge as macOS framework
project(Live2DBridge)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 14.0)

# Paths
set(SDK_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../CubismSdkForNative-5-r.5)
set(BRIDGE_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../..)
set(CORE_PATH ${SDK_ROOT_PATH}/Core)
set(CUBISM_LIB_PATH ${SDK_ROOT_PATH}/Core/lib/macos/arm64)
set(FRAMEWORK_LIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../lib)

# Add Cubism Core as imported static library
add_library(Live2DCubismCore STATIC IMPORTED)
set_target_properties(Live2DCubismCore
  PROPERTIES
    IMPORTED_LOCATION ${CUBISM_LIB_PATH}/libLive2DCubismCore.a
    INTERFACE_INCLUDE_DIRECTORIES ${CORE_PATH}/include
)

# Add pre-built Cubism Framework
add_library(AriaCubism STATIC IMPORTED)
set_target_properties(AriaCubism
  PROPERTIES
    IMPORTED_LOCATION ${FRAMEWORK_LIB_PATH}/libAriaCubism.a
    INTERFACE_INCLUDE_DIRECTORIES ${SDK_ROOT_PATH}/Framework/src
)

# Create bridge as static library for easier SPM integration
add_library(Live2DBridge STATIC
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge/ARLive2D.m
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge/Live2DBridge.mm
)

# Add include paths
target_include_directories(Live2DBridge
  PUBLIC
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge/include
  PRIVATE
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge
    ${CORE_PATH}/include
    ${SDK_ROOT_PATH}/Framework/src
    ${SDK_ROOT_PATH}/Framework/src/Rendering/Metal
)

# Link libraries
target_link_libraries(Live2DBridge
  PRIVATE
    Live2DCubismCore
    AriaCubism
)

# Find required Apple frameworks
find_library(FOUNDATION_LIBRARY Foundation)
find_library(METAL_LIBRARY Metal)
find_library(METALKIT_LIBRARY MetalKit)
find_library(QUARTZCORE_LIBRARY QuartzCore)
find_library(COREGRAPHICS_LIBRARY CoreGraphics)

# Link frameworks
target_link_libraries(Live2DBridge
  PRIVATE
    ${FOUNDATION_LIBRARY}
    ${METAL_LIBRARY}
    ${METALKIT_LIBRARY}
    ${QUARTZCORE_LIBRARY}
    ${COREGRAPHICS_LIBRARY}
)

# Disable ARC for Objective-C++ files only
set_source_files_properties(
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge/Live2DBridge.mm
    PROPERTIES
    COMPILE_FLAGS "-fno-objc-arc"
)

# Disable ARC for Objective-C wrapper (manual memory management)
set_source_files_properties(
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge/ARLive2D.m
    PROPERTIES
    COMPILE_FLAGS "-fno-objc-arc"
)

# Enable ARC for Objective-C wrapper
set_source_files_properties(
    ${BRIDGE_ROOT_PATH}/Sources/Live2DBridge/ARLive2D.m
    PROPERTIES
    COMPILE_FLAGS "-fobjc-arc"
)

# Set output directory
set_target_properties(Live2DBridge
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../Lib
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../Lib
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../Lib
)

message(STATUS "Building Live2DBridge Static Library")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "macOS Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "Output: ${CMAKE_CURRENT_SOURCE_DIR}/../Lib")