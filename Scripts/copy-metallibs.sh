#!/bin/bash

# Script to copy Live2D Metal shader libraries to the SPM build directory
# Usage: ./Scripts/copy-metallibs.sh [debug|release]
# Default: debug

set -e

# Configuration
SOURCE_DIR="ThirdParty/Live2D/CubismSdkForNative-5-r.5/Framework/src/Rendering/Metal/Shaders/FrameworkMetallibs"
BUILD_BASE=".build/arm64-apple-macosx"
METALLIB_DIR="FrameworkMetallibs"

# Detect configuration (default to debug)
CONFIG="${1:-debug}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "Error: Invalid configuration '$CONFIG'. Use 'debug' or 'release'."
    exit 1
fi

# Construct paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PATH="$PROJECT_ROOT/$SOURCE_DIR"
DEST_PATH="$PROJECT_ROOT/$BUILD_BASE/$CONFIG/$METALLIB_DIR"

echo "Copying Metal shader libraries..."
echo "Source: $SOURCE_PATH"
echo "Destination: $DEST_PATH"
echo "Configuration: $CONFIG"

# Check if source directory exists
if [[ ! -d "$SOURCE_PATH" ]]; then
    echo "Error: Source directory not found: $SOURCE_PATH"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_PATH"

# Copy all .metallib files
cp -v "$SOURCE_PATH"/*.metallib "$DEST_PATH/"

echo "✓ Metal shader libraries copied successfully for $CONFIG configuration"
