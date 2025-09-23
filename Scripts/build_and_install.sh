#!/bin/bash

# ParqView Build and Install Script
# This script builds ParqView and installs it to /Applications, replacing any existing version

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ParqView Build and Install Script ===${NC}"
echo ""

# Step 1: Clean previous builds
echo -e "${YELLOW}Step 1: Cleaning previous builds...${NC}"
rm -rf .build
rm -rf build
swift package clean
echo -e "${GREEN}✓ Cleaned${NC}"
echo ""

# Step 2: Build the app in release mode
echo -e "${YELLOW}Step 2: Building ParqView in release mode...${NC}"
swift build -c release --product ParqViewApp
echo -e "${GREEN}✓ Built successfully${NC}"
echo ""

# Step 3: Create app bundle structure
echo -e "${YELLOW}Step 3: Creating app bundle...${NC}"
APP_NAME="ParqView"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Remove old build directory if it exists
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create app bundle directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/ParqViewApp" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "Info.plist" "$CONTENTS_DIR/"

# Copy icon if it exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/"
    echo "✓ Icon added"
else
    echo "⚠ No icon found, creating one..."
    python3 create_icon.py 2>/dev/null || echo "  Could not create icon"
    if [ -f "AppIcon.icns" ]; then
        cp "AppIcon.icns" "$RESOURCES_DIR/"
    fi
fi

# Create PkgInfo file
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo -e "${GREEN}✓ App bundle created${NC}"
echo ""

# Step 4: Code sign the app (ad-hoc signing for local use)
echo -e "${YELLOW}Step 4: Code signing the app...${NC}"
codesign --force --deep --sign - "$APP_BUNDLE"
echo -e "${GREEN}✓ Code signed${NC}"
echo ""

# Step 5: Check for existing installations
echo -e "${YELLOW}Step 5: Checking for existing installations...${NC}"

# Kill any running instances
if pgrep -x "ParqView" > /dev/null; then
    echo "Found running ParqView instance, terminating..."
    pkill -x "ParqView" || true
    sleep 1
fi

# Remove existing installations
if [ -d "/Applications/$APP_NAME.app" ]; then
    echo "Found existing installation in /Applications, removing..."
    rm -rf "/Applications/$APP_NAME.app"
fi

if [ -d "$HOME/Applications/$APP_NAME.app" ]; then
    echo "Found existing installation in ~/Applications, removing..."
    rm -rf "$HOME/Applications/$APP_NAME.app"
fi

echo -e "${GREEN}✓ Cleaned up existing installations${NC}"
echo ""

# Step 6: Install to /Applications
echo -e "${YELLOW}Step 6: Installing to /Applications...${NC}"
cp -R "$APP_BUNDLE" "/Applications/"
echo -e "${GREEN}✓ Installed to /Applications/$APP_NAME.app${NC}"
echo ""

# Step 7: Reset Launch Services database
echo -e "${YELLOW}Step 7: Resetting Launch Services database...${NC}"
# Kill and reset the Launch Services database
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
# Register our app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP_NAME.app"
echo -e "${GREEN}✓ Launch Services database updated${NC}"
echo ""

# Step 8: Set file associations
echo -e "${YELLOW}Step 8: Setting file associations...${NC}"
# Remove any existing handlers for parquet files
defaults delete com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers 2>/dev/null || true

# Add our app as the handler for parquet files
defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add \
    '{LSHandlerContentType="org.apache.parquet";LSHandlerRoleAll="com.parqview.ParqView";}'
    
# Also register for the file extensions directly
defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add \
    '{LSHandlerContentTag="parquet";LSHandlerContentTagClass="public.filename-extension";LSHandlerRoleAll="com.parqview.ParqView";}'
    
defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add \
    '{LSHandlerContentTag="parq";LSHandlerContentTagClass="public.filename-extension";LSHandlerRoleAll="com.parqview.ParqView";}'

# Force update
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP_NAME.app"

echo -e "${GREEN}✓ File associations configured${NC}"
echo ""

# Step 9: Verify installation
echo -e "${YELLOW}Step 9: Verifying installation...${NC}"
if [ -f "/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME" ]; then
    echo -e "${GREEN}✓ Installation verified${NC}"
    echo ""
    echo -e "${GREEN}=== Installation Complete ===${NC}"
    echo ""
    echo "ParqView has been successfully installed to /Applications/"
    echo ""
    echo "You can now:"
    echo "  1. Open ParqView from /Applications"
    echo "  2. Double-click any .parquet file to open it with ParqView"
    echo "  3. Right-click a .parquet file and choose 'Open With' > 'ParqView'"
    echo ""
    echo "To test the app, run:"
    echo "  open /Applications/$APP_NAME.app"
    echo ""
    echo "To test with a sample file, run:"
    echo "  open -a ParqView /path/to/your/file.parquet"
else
    echo -e "${RED}✗ Installation verification failed${NC}"
    exit 1
fi