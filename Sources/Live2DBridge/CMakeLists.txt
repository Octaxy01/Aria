cmake_minimum_required(VERSION 3.16)
project(Live2DBridge)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Metal frameworks
find_library(METAL_LIBRARY Metal)
find_library(METALKIT_LIBRARY MetalKit)
find_library(QUARTZCORE_LIBRARY QuartzCore)
find_library(FOUNDATION_LIBRARY Foundation)

# Add Live2D Core
add_library(Live2DCubismCore STATIC IMPORTED)
set_target_properties(Live2DCubismCore
  PROPERTIES
    IMPORTED_LOCATION ../../ThirdParty/Live2D/CubismSdkForNative-5-r.5/Core/lib/macos/arm64/libLive2DCubismCore.a
    INTERFACE_INCLUDE_DIRECTORIES ../../ThirdParty/Live2D/CubismSdkForNative-5-r.5/Core/include
)

# Create the bridge library
add_library(Live2DBridge SHARED
    Live2DBridge.mm
    Live2DBridge.h
)

target_include_directories(Live2DBridge PRIVATE
    ../../ThirdParty/Live2D/CubismSdkForNative-5-r.5/Core/include
    ../../ThirdParty/Live2D/CubismSdkForNative-5-r.5/Framework/src
)

target_link_libraries(Live2DBridge
    Live2DCubismCore
    ${METAL_LIBRARY}
    ${METALKIT_LIBRARY}
    ${QUARTZCORE_LIBRARY}
    ${FOUNDATION_LIBRARY}
)