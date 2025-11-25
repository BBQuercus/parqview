#!/bin/bash

# Build script for ParqView.app
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "Building ParqView.app..."

# Clean previous builds
rm -rf .build/ParqView.app

# Build the executable in release mode
echo "Compiling..."
swift build -c release

# Create app bundle structure
echo "Creating app bundle..."
mkdir -p .build/ParqView.app/Contents/MacOS
mkdir -p .build/ParqView.app/Contents/Resources

# Copy executable (detect architecture)
if [ -f ".build/release/ParqViewApp" ]; then
    cp .build/release/ParqViewApp .build/ParqView.app/Contents/MacOS/ParqView
elif [ -f ".build/arm64-apple-macosx/release/ParqViewApp" ]; then
    cp .build/arm64-apple-macosx/release/ParqViewApp .build/ParqView.app/Contents/MacOS/ParqView
else
    echo "Error: Could not find built executable"
    exit 1
fi

# Copy Info.plist
cp Info.plist .build/ParqView.app/Contents/

# Make executable
chmod +x .build/ParqView.app/Contents/MacOS/ParqView

# Copy Assets.xcassets
echo "Copying assets..."
cp -r Sources/ParqViewApp/Resources/Assets.xcassets .build/ParqView.app/Contents/Resources/ 2>/dev/null || true

# Function to create icon from PNG
create_icon_from_png() {
    local src_png="$1"
    local dest_icns="$2"

    # Create isolated temporary directory
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local iconset="$tmpdir/AppIcon.iconset"
    mkdir -p "$iconset"

    # Generate all required sizes
    sips -z 16 16     "$src_png" --out "$iconset/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$src_png" --out "$iconset/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$src_png" --out "$iconset/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$src_png" --out "$iconset/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$src_png" --out "$iconset/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$src_png" --out "$iconset/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$src_png" --out "$iconset/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$src_png" --out "$iconset/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$src_png" --out "$iconset/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$src_png" --out "$iconset/icon_512x512@2x.png" >/dev/null 2>&1

    # Create .icns file
    iconutil -c icns "$iconset" -o "$dest_icns" 2>/dev/null
}

# Create app icon
ICON_DEST=".build/ParqView.app/Contents/Resources/AppIcon.icns"

if [ -d "AppIcon.iconset" ]; then
    echo "Converting existing iconset to .icns..."
    iconutil -c icns AppIcon.iconset -o "$ICON_DEST" 2>/dev/null || echo "Warning: Could not create .icns file"
elif [ -f "icon_formatted.png" ]; then
    echo "Creating icon from icon_formatted.png..."
    create_icon_from_png "icon_formatted.png" "$ICON_DEST" || echo "Warning: Could not create .icns file"
elif [ -f "icon.png" ]; then
    echo "Creating icon from icon.png..."
    create_icon_from_png "icon.png" "$ICON_DEST" || echo "Warning: Could not create .icns file"
else
    echo "Warning: No icon source found"
fi

echo ""
echo "Build complete! App bundle created at: .build/ParqView.app"
echo ""
echo "To run the app:"
echo "  open .build/ParqView.app"
echo ""
echo "To install to Applications:"
echo "  cp -r .build/ParqView.app /Applications/"
