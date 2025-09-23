#!/bin/bash

# Bundle Arrow/Parquet libraries with the app
set -e

APP_PATH=".build/ParqView.app"
FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/ParqView"

echo "Bundling dependencies into $APP_PATH..."

# Create Frameworks directory
mkdir -p "$FRAMEWORKS_PATH"

# Find and copy Arrow/Parquet libraries
echo "Finding Arrow and Parquet libraries..."

# Function to copy library and update references
copy_and_update_lib() {
    local lib_path=$1
    local lib_name=$(basename "$lib_path")
    
    if [ -f "$lib_path" ]; then
        echo "  Copying $lib_name..."
        cp "$lib_path" "$FRAMEWORKS_PATH/"
        
        # Update the executable to reference the bundled library
        install_name_tool -change "$lib_path" "@executable_path/../Frameworks/$lib_name" "$EXECUTABLE_PATH" 2>/dev/null || true
        
        # Make the library reference itself relatively
        install_name_tool -id "@executable_path/../Frameworks/$lib_name" "$FRAMEWORKS_PATH/$lib_name" 2>/dev/null || true
        
        # Check for dependencies of this library
        otool -L "$FRAMEWORKS_PATH/$lib_name" | grep -E "(arrow|parquet)" | awk '{print $1}' | while read dep; do
            if [[ "$dep" != "@executable_path"* ]]; then
                local dep_name=$(basename "$dep")
                install_name_tool -change "$dep" "@executable_path/../Frameworks/$dep_name" "$FRAMEWORKS_PATH/$lib_name" 2>/dev/null || true
            fi
        done
    fi
}

# Find actual library paths from the binary
echo "Detecting library dependencies..."
LIBS_TO_COPY=$(otool -L "$EXECUTABLE_PATH" | grep -E "(arrow|parquet)" | awk '{print $1}')

# Copy each library
for lib_path in $LIBS_TO_COPY; do
    if [ -f "$lib_path" ]; then
        copy_and_update_lib "$lib_path"
    fi
done

# Also copy any additional Arrow dependencies
echo "Checking for additional dependencies..."
for framework in "$FRAMEWORKS_PATH"/*.dylib; do
    if [ -f "$framework" ]; then
        otool -L "$framework" | grep -v "@executable_path" | grep -E "\.dylib" | awk '{print $1}' | while read dep; do
            if [[ "$dep" == "/opt/homebrew/"* ]] || [[ "$dep" == "/usr/local/"* ]]; then
                if [ -f "$dep" ]; then
                    dep_name=$(basename "$dep")
                    if [ ! -f "$FRAMEWORKS_PATH/$dep_name" ]; then
                        echo "  Adding dependency: $dep_name"
                        cp "$dep" "$FRAMEWORKS_PATH/"
                        
                        # Update all frameworks to reference this new dependency
                        for fw in "$FRAMEWORKS_PATH"/*.dylib; do
                            install_name_tool -change "$dep" "@executable_path/../Frameworks/$dep_name" "$fw" 2>/dev/null || true
                        done
                        install_name_tool -change "$dep" "@executable_path/../Frameworks/$dep_name" "$EXECUTABLE_PATH" 2>/dev/null || true
                    fi
                fi
            fi
        done
    fi
done

# Fix any remaining absolute paths in the main executable
echo "Fixing library paths in executable..."
otool -L "$EXECUTABLE_PATH" | grep -E "(arrow|parquet)" | awk '{print $1}' | while read lib; do
    if [[ "$lib" != "@executable_path"* ]]; then
        lib_name=$(basename "$lib")
        if [ -f "$FRAMEWORKS_PATH/$lib_name" ]; then
            install_name_tool -change "$lib" "@executable_path/../Frameworks/$lib_name" "$EXECUTABLE_PATH"
        fi
    fi
done

# Verify the bundle
echo ""
echo "Verifying bundled libraries..."
echo "Main executable dependencies:"
otool -L "$EXECUTABLE_PATH" | grep -E "(arrow|parquet)" || echo "  No Arrow/Parquet dependencies found (might be statically linked)"

echo ""
echo "Bundled frameworks:"
ls -lh "$FRAMEWORKS_PATH" 2>/dev/null | grep dylib || echo "  No frameworks bundled"

echo ""
echo "Bundle complete! The app should now be self-contained."
echo "Note: This increases the app size but removes the need for users to install dependencies."