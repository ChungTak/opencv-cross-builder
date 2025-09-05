#!/bin/bash

# Build Validation Script
# This script validates the build output to ensure all required files are present

set -e

TARGET="$1"
OUTPUT_DIR="$2"

if [ -z "$TARGET" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <target> <output_dir>"
    exit 1
fi

echo "Validating build for target: $TARGET"
echo "Output directory: $OUTPUT_DIR"

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "ERROR: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Required directories
REQUIRED_DIRS=()
OPTIONAL_DIRS=("pkgconfig" "bin")

# Determine actual directory structure based on target platform
if [[ "$TARGET" == *"-linux-android"* ]]; then
    # Android uses SDK directory structure
    INCLUDE_DIR="sdk/native/jni/include"
    LIB_DIRS=("sdk/native/libs" "sdk/native/3rdparty/libs")
    echo "Using Android SDK directory structure"
else
    # Standard platforms (including HarmonyOS) use traditional structure
    INCLUDE_DIR="include"
    LIB_DIRS=("lib")
    echo "Using standard directory structure"
fi

# Add include directory to required directories
REQUIRED_DIRS+=("$INCLUDE_DIR")

echo "Checking required directories..."
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$OUTPUT_DIR/$dir" ]; then
        echo "ERROR: Required directory missing: $dir"
        echo "Available directories in $OUTPUT_DIR:"
        ls -la "$OUTPUT_DIR/" 2>/dev/null || echo "Cannot list directory contents"
        if [ -d "$OUTPUT_DIR/sdk" ]; then
            echo "SDK directory contents:"
            find "$OUTPUT_DIR/sdk" -type d -maxdepth 3 2>/dev/null || echo "Cannot explore SDK directory"
        fi
        exit 1
    fi
    echo "✓ Found: $dir"
done

# Check for library directories (Android may have multiple possible locations)
LIB_DIR_FOUND=""
if [[ "$TARGET" == *"-linux-android"* ]]; then
    # For Android, check multiple possible library locations
    case "$TARGET" in
        aarch64-linux-android)
            ARCH_DIRS=("arm64-v8a")
            ;;
        arm-linux-android)
            ARCH_DIRS=("armeabi-v7a")
            ;;
        x86_64-linux-android)
            ARCH_DIRS=("x86_64")
            ;;
        x86-linux-android)
            ARCH_DIRS=("x86")
            ;;
        *)
            ARCH_DIRS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")
            ;;
    esac
    
    for lib_base in "${LIB_DIRS[@]}"; do
        for arch_dir in "${ARCH_DIRS[@]}"; do
            for lib_path in "$OUTPUT_DIR/$lib_base/$arch_dir" "$OUTPUT_DIR/$lib_base"; do
                if [ -d "$lib_path" ] && [ "$(find "$lib_path" -name "*.a" -o -name "*.so*" 2>/dev/null | wc -l)" -gt 0 ]; then
                    LIB_DIR_FOUND="$lib_path"
                    echo "✓ Found library directory: $lib_path"
                    break 3
                fi
            done
        done
    done
    
    # If still not found, search in SDK directory
    if [ -z "$LIB_DIR_FOUND" ] && [ -d "$OUTPUT_DIR/sdk" ]; then
        LIB_SEARCH_RESULT=$(find "$OUTPUT_DIR/sdk" -name "*.a" -o -name "*.so*" 2>/dev/null | head -1)
        if [ -n "$LIB_SEARCH_RESULT" ]; then
            LIB_DIR_FOUND=$(dirname "$LIB_SEARCH_RESULT")
            echo "✓ Found library directory through search: $LIB_DIR_FOUND"
        fi
    fi
else
    # Standard platform (including HarmonyOS) - check traditional lib directory
    if [ -d "$OUTPUT_DIR/lib" ]; then
        LIB_DIR_FOUND="$OUTPUT_DIR/lib"
        echo "✓ Found: lib"
    fi
fi

if [ -z "$LIB_DIR_FOUND" ]; then
    echo "ERROR: No library directory found"
    echo "Searched locations:"
    for lib_base in "${LIB_DIRS[@]}"; do
        echo "  - $OUTPUT_DIR/$lib_base"
    done
    exit 1
fi

echo "Checking optional directories..."
for dir in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "$OUTPUT_DIR/$dir" ]; then
        echo "✓ Found: $dir"
    else
        echo "- Missing (optional): $dir"
    fi
done

# Check for header files
echo "Checking for header files..."
HEADER_COUNT=$(find "$OUTPUT_DIR/$INCLUDE_DIR" -name "*.h" 2>/dev/null | wc -l)
if [ "$HEADER_COUNT" -eq 0 ]; then
    echo "ERROR: No header files found in $INCLUDE_DIR directory"
    exit 1
fi
echo "✓ Found $HEADER_COUNT header files"

# Check for library files
echo "Checking for library files..."
LIB_COUNT=0

# Check for different library types based on target
case "$TARGET" in
    *-windows-*)
        LIB_COUNT=$(find "$LIB_DIR_FOUND" -name "*.lib" -o -name "*.dll" -o -name "*.a" 2>/dev/null | wc -l)
        ;;
    *-macos*)
        LIB_COUNT=$(find "$LIB_DIR_FOUND" -name "*.a" -o -name "*.dylib" 2>/dev/null | wc -l)
        ;;
    *)
        LIB_COUNT=$(find "$LIB_DIR_FOUND" -name "*.a" -o -name "*.so*" 2>/dev/null | wc -l)
        ;;
esac

if [ "$LIB_COUNT" -eq 0 ]; then
    echo "ERROR: No library files found in library directory: $LIB_DIR_FOUND"
    exit 1
fi
echo "✓ Found $LIB_COUNT library files"

# List all files for debugging
echo "Build output contents:"
find "$OUTPUT_DIR" -type f | head -20
if [ $(find "$OUTPUT_DIR" -type f | wc -l) -gt 20 ]; then
    echo "... and $(( $(find "$OUTPUT_DIR" -type f | wc -l) - 20 )) more files"
fi

# Calculate total size
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "Total build size: $TOTAL_SIZE"

echo "✓ Build validation successful for $TARGET"
