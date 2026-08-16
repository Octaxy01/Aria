#!/bin/bash

# Build script for Live2D Bridge Framework
# This builds the native Objective-C++ bridge that links to the Cubism Framework

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRIDGE_DIR="$PROJECT_ROOT/ThirdParty/Live2D/Bridge"
LIB_DIR="$PROJECT_ROOT/ThirdParty/Live2D/Lib"

echo "Building Live2D Bridge Static Library..."
echo "Project root: $PROJECT_ROOT"
echo "Bridge directory: $BRIDGE_DIR"

# Create build directory
mkdir -p "$BRIDGE_DIR/build"
mkdir -p "$LIB_DIR"

# Configure with CMake
cd "$BRIDGE_DIR/build"
cmake .. -DCMAKE_BUILD_TYPE=Release

# Build
make

echo "Live2D Bridge Static Library built successfully!"
echo "Library location: $LIB_DIR/libLive2DBridge.a"

# Verify the library exists
if [ -f "$LIB_DIR/libLive2DBridge.a" ]; then
    echo "✓ Library file verified"
    file "$LIB_DIR/libLive2DBridge.a"
else
    echo "✗ Library file not found"
    exit 1
fi