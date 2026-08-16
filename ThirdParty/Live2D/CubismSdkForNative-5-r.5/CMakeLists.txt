cmake_minimum_required(VERSION 3.16)

# Build Cubism Framework as static library for macOS
project(AriaCubism)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set architecture to arm64 for Apple Silicon
set(CMAKE_OSX_ARCHITECTURES arm64)

# Set minimum macOS version
set(CMAKE_OSX_DEPLOYMENT_TARGET 14.0)

# Set platform name for shader compilation
set(PLATFORM_NAME macosx)

# Paths
set(SDK_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_PATH ${SDK_ROOT_PATH}/Core)
set(FRAMEWORK_PATH ${SDK_ROOT_PATH}/Framework)

# Add Cubism Core as imported static library
add_library(Live2DCubismCore STATIC IMPORTED)
set_target_properties(Live2DCubismCore
  PROPERTIES
    IMPORTED_LOCATION ${CORE_PATH}/lib/macos/arm64/libLive2DCubismCore.a
    INTERFACE_INCLUDE_DIRECTORIES ${CORE_PATH}/include
)

# Specify Cubism Framework rendering backend
set(FRAMEWORK_SOURCE Metal)

# Add Cubism Native Framework
add_subdirectory(${FRAMEWORK_PATH} ${CMAKE_CURRENT_BINARY_DIR}/Framework)

# Add rendering definition to framework
target_compile_definitions(Framework PUBLIC CSM_TARGET_MACOS)

# Link libraries to framework
target_link_libraries(Framework Live2DCubismCore)

# Find required Apple frameworks
find_library(COREGRAPHICS_LIBRARY CoreGraphics)
find_library(FOUNDATION_LIBRARY Foundation)
find_library(METALKIT_LIBRARY MetalKit)
find_library(METAL_LIBRARY Metal)
find_library(QUARTZCORE_LIBRARY QuartzCore)
find_library(APPSERVICES_LIBRARY ApplicationServices)

# Link frameworks to the Cubism Framework
target_link_libraries(Framework
  ${COREGRAPHICS_LIBRARY}
  ${FOUNDATION_LIBRARY}
  ${METALKIT_LIBRARY}
  ${METAL_LIBRARY}
  ${QUARTZCORE_LIBRARY}
  ${APPSERVICES_LIBRARY}
)

# Disable ARC for Objective-C++ files
set_target_properties(Framework
  PROPERTIES
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC NO
)

# Add include paths
target_include_directories(Framework
  PUBLIC
    ${FRAMEWORK_PATH}/src
  PRIVATE
    ${CORE_PATH}/include
)

# Output library name
set_target_properties(Framework PROPERTIES OUTPUT_NAME "AriaCubism")

message(STATUS "Building AriaCubism for macOS arm64")
message(STATUS "Rendering backend: Metal")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "macOS Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")