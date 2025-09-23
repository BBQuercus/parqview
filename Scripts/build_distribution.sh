#!/bin/bash

# Distribution build script for ParqView.app
# Creates a universal binary for both Intel and Apple Silicon Macs
set -e

echo "========================================="
echo "ParqView Distribution Build Script"
echo "========================================="

# Configuration
APP_NAME="ParqView"
BUNDLE_ID="com.parqview.ParqView"
VERSION="1.0.0"

# Parse command line arguments
SIGN_APP=false
NOTARIZE=false
CREATE_DMG=false
DEVELOPER_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN_APP=true
            shift
            ;;
        --developer-id)
            DEVELOPER_ID="$2"
            SIGN_APP=true
            shift 2
            ;;
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --sign              Sign the app (requires Developer ID)"
            echo "  --developer-id ID   Specify Developer ID for signing"
            echo "  --notarize          Notarize the app (requires signing)"
            echo "  --dmg               Create a DMG installer"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf .build/ParqView.app
rm -rf .build/universal
rm -f ParqView.dmg

# Build for both architectures
echo "Building for multiple architectures..."

# Build for ARM64 (Apple Silicon)
echo "  - Building for ARM64..."
swift build -c release --arch arm64

# Build for x86_64 (Intel)
echo "  - Building for x86_64..."
swift build -c release --arch x86_64 2>/dev/null || {
    echo "  ⚠️  Warning: x86_64 build failed. This might be expected on Apple Silicon."
    echo "     Creating ARM64-only build instead of universal binary."
    ARM_ONLY=true
}

# Create universal binary if both architectures built successfully
echo "Creating app bundle..."
mkdir -p .build/ParqView.app/Contents/MacOS
mkdir -p .build/ParqView.app/Contents/Resources

if [ -z "$ARM_ONLY" ] && [ -f ".build/x86_64-apple-macosx/release/ParqViewApp" ]; then
    echo "Creating universal binary..."
    lipo -create \
        .build/arm64-apple-macosx/release/ParqViewApp \
        .build/x86_64-apple-macosx/release/ParqViewApp \
        -output .build/ParqView.app/Contents/MacOS/ParqView
    echo "  ✓ Universal binary created (Intel + Apple Silicon)"
else
    echo "Creating ARM64-only binary..."
    cp .build/arm64-apple-macosx/release/ParqViewApp .build/ParqView.app/Contents/MacOS/ParqView
    echo "  ✓ ARM64 binary created (Apple Silicon only)"
fi

# Make executable
chmod +x .build/ParqView.app/Contents/MacOS/ParqView

# Copy Info.plist
cp Info.plist .build/ParqView.app/Contents/

# Copy Assets
echo "Copying resources..."
cp -r Sources/ParqViewApp/Resources/Assets.xcassets .build/ParqView.app/Contents/Resources/ 2>/dev/null || true

# Create icon
if [ -d "AppIcon.iconset" ]; then
    echo "Creating app icon..."
    iconutil -c icns AppIcon.iconset -o .build/ParqView.app/Contents/Resources/AppIcon.icns 2>/dev/null || echo "  ⚠️  Warning: Could not create .icns file"
fi

# Bundle dependencies
if [ -f "bundle_dependencies.sh" ]; then
    echo ""
    echo "Bundling dependencies..."
    chmod +x bundle_dependencies.sh
    ./bundle_dependencies.sh || echo "  ⚠️  Warning: Could not bundle all dependencies"
fi

# Check architecture of final binary
echo ""
echo "Binary architecture info:"
lipo -info .build/ParqView.app/Contents/MacOS/ParqView

# Check dependencies
echo ""
echo "Checking dependencies..."
otool -L .build/ParqView.app/Contents/MacOS/ParqView | head -10

# Sign the app if requested
if [ "$SIGN_APP" = true ]; then
    if [ -z "$DEVELOPER_ID" ]; then
        # Try to find Developer ID automatically
        DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    fi
    
    if [ -n "$DEVELOPER_ID" ]; then
        echo ""
        echo "Signing app with Developer ID: $DEVELOPER_ID"
        
        # Sign all frameworks and dylibs first
        find .build/ParqView.app -name "*.dylib" -o -name "*.framework" | while read -r lib; do
            codesign --force --sign "$DEVELOPER_ID" --timestamp "$lib"
        done
        
        # Sign the main executable
        codesign --force --sign "$DEVELOPER_ID" --timestamp \
            --options runtime \
            --entitlements Entitlements.plist \
            .build/ParqView.app
        
        echo "  ✓ App signed successfully"
        
        # Verify signature
        echo "Verifying signature..."
        codesign --verify --deep --strict .build/ParqView.app
        spctl -a -t exec -vv .build/ParqView.app
    else
        echo "  ⚠️  Warning: No Developer ID found. App will not be signed."
        echo "     Users will see a security warning when opening the app."
    fi
fi

# Notarize if requested (requires signing)
if [ "$NOTARIZE" = true ] && [ "$SIGN_APP" = true ]; then
    echo ""
    echo "Notarizing app..."
    echo "  Note: This requires Apple Developer account credentials"
    
    # Create zip for notarization
    ditto -c -k --keepParent .build/ParqView.app ParqView.zip
    
    # Submit for notarization
    xcrun notarytool submit ParqView.zip \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait
    
    # Staple the notarization
    xcrun stapler staple .build/ParqView.app
    
    # Clean up
    rm ParqView.zip
    
    echo "  ✓ App notarized successfully"
fi

# Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    echo ""
    echo "Creating DMG installer..."
    
    # Create temporary DMG directory
    mkdir -p .build/dmg
    cp -r .build/ParqView.app .build/dmg/
    ln -s /Applications .build/dmg/Applications
    
    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder .build/dmg \
        -ov -format UDZO \
        ParqView.dmg
    
    # Clean up
    rm -rf .build/dmg
    
    if [ "$SIGN_APP" = true ] && [ -n "$DEVELOPER_ID" ]; then
        echo "Signing DMG..."
        codesign --sign "$DEVELOPER_ID" ParqView.dmg
    fi
    
    echo "  ✓ DMG created: ParqView.dmg"
fi

# Final summary
echo ""
echo "========================================="
echo "Build Summary"
echo "========================================="
echo "✓ App bundle created at: .build/ParqView.app"

# Check file size
APP_SIZE=$(du -sh .build/ParqView.app | cut -f1)
echo "  Size: $APP_SIZE"

# Architecture info
ARCH_INFO=$(lipo -info .build/ParqView.app/Contents/MacOS/ParqView 2>&1 | sed 's/.*: //')
echo "  Architecture: $ARCH_INFO"

# macOS version requirement
echo "  Minimum macOS: 13.0 (Ventura)"

if [ "$SIGN_APP" = true ] && [ -n "$DEVELOPER_ID" ]; then
    echo "  Signed: Yes"
else
    echo "  Signed: No (users will see security warning)"
fi

if [ "$CREATE_DMG" = true ]; then
    DMG_SIZE=$(du -h ParqView.dmg | cut -f1)
    echo "  DMG: ParqView.dmg ($DMG_SIZE)"
fi

echo ""
echo "Distribution Notes:"
echo "  - The app requires macOS 13.0 (Ventura) or later"
echo "  - Users need Apache Arrow and Parquet libraries installed"
echo "    Install with: brew install apache-arrow"

if [ "$SIGN_APP" = false ]; then
    echo ""
    echo "  ⚠️  For distribution without signing:"
    echo "     Users will need to right-click and select 'Open' on first launch"
    echo "     or go to System Settings > Privacy & Security to allow the app"
fi

echo ""
echo "To test the app:"
echo "  open .build/ParqView.app"
echo ""
echo "To distribute:"
if [ "$CREATE_DMG" = true ]; then
    echo "  Share the ParqView.dmg file"
else
    echo "  1. Compress: zip -r ParqView.zip .build/ParqView.app"
    echo "  2. Share the zip file"
fi