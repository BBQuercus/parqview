#!/bin/bash

# Build script for ParqView.app
set -e

echo "Building ParqView.app..."

# Clean previous builds
rm -rf .build/ParqView.app

# Build the executable in release mode
echo "Compiling..."
swift build -c release --arch arm64

# Create app bundle structure
echo "Creating app bundle..."
mkdir -p .build/ParqView.app/Contents/MacOS
mkdir -p .build/ParqView.app/Contents/Resources

# Copy executable
cp .build/arm64-apple-macosx/release/ParqViewApp .build/ParqView.app/Contents/MacOS/ParqView

# Copy Info.plist
cp Info.plist .build/ParqView.app/Contents/

# Make executable
chmod +x .build/ParqView.app/Contents/MacOS/ParqView

# Copy Assets.xcassets
echo "Copying assets..."
cp -r Sources/ParqViewApp/Resources/Assets.xcassets .build/ParqView.app/Contents/Resources/ 2>/dev/null || true

# Use the formatted iconset if it exists, otherwise try to create it
if [ -d "AppIcon.iconset" ]; then
    echo "Converting iconset to .icns..."
    # Create .icns file from the formatted iconset
    iconutil -c icns AppIcon.iconset -o .build/ParqView.app/Contents/Resources/AppIcon.icns 2>/dev/null || echo "Warning: Could not create .icns file"
elif [ -f "icon_formatted.png" ]; then
    echo "Using formatted icon..."
    # Create temporary directory
    mkdir -p /tmp/AppIcon.iconset
    
    # Use sips to resize the formatted icon to all required sizes
    sips -z 16 16     icon_formatted.png --out /tmp/AppIcon.iconset/icon_16x16.png >/dev/null 2>&1
    sips -z 32 32     icon_formatted.png --out /tmp/AppIcon.iconset/icon_16x16@2x.png >/dev/null 2>&1
    sips -z 32 32     icon_formatted.png --out /tmp/AppIcon.iconset/icon_32x32.png >/dev/null 2>&1
    sips -z 64 64     icon_formatted.png --out /tmp/AppIcon.iconset/icon_32x32@2x.png >/dev/null 2>&1
    sips -z 128 128   icon_formatted.png --out /tmp/AppIcon.iconset/icon_128x128.png >/dev/null 2>&1
    sips -z 256 256   icon_formatted.png --out /tmp/AppIcon.iconset/icon_128x128@2x.png >/dev/null 2>&1
    sips -z 256 256   icon_formatted.png --out /tmp/AppIcon.iconset/icon_256x256.png >/dev/null 2>&1
    sips -z 512 512   icon_formatted.png --out /tmp/AppIcon.iconset/icon_256x256@2x.png >/dev/null 2>&1
    sips -z 512 512   icon_formatted.png --out /tmp/AppIcon.iconset/icon_512x512.png >/dev/null 2>&1
    sips -z 1024 1024 icon_formatted.png --out /tmp/AppIcon.iconset/icon_512x512@2x.png >/dev/null 2>&1
    
    # Create .icns file
    iconutil -c icns /tmp/AppIcon.iconset -o .build/ParqView.app/Contents/Resources/AppIcon.icns 2>/dev/null || echo "Warning: Could not create .icns file"
    
    # Clean up
    rm -rf /tmp/AppIcon.iconset
else
    echo "No formatted icon found, using original icon.png as fallback..."
    if [ -f "icon.png" ]; then
        # Run the format script if available
        if [ -f "format_icon.py" ] && [ -f ".venv/bin/python3" ]; then
            echo "Formatting icon..."
            .venv/bin/python3 format_icon.py
            # Now use the generated iconset
            if [ -d "AppIcon.iconset" ]; then
                iconutil -c icns AppIcon.iconset -o .build/ParqView.app/Contents/Resources/AppIcon.icns 2>/dev/null || echo "Warning: Could not create .icns file"
            fi
        fi
    fi
fi

echo "Build complete! App bundle created at: .build/ParqView.app"
echo ""
echo "To run the app:"
echo "  open .build/ParqView.app"
echo ""
echo "To install to Applications:"
echo "  cp -r .build/ParqView.app /Applications/"