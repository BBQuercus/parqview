#!/bin/bash

# Verification script for ParqView installation

echo "ParqView Installation Verification"
echo "==================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if app exists
echo "1. Checking app installation..."
if [ -d "/Applications/ParqView.app" ]; then
    echo -e "   ${GREEN}✓ ParqView.app found in /Applications${NC}"
else
    echo -e "   ${RED}✗ ParqView.app not found in /Applications${NC}"
    exit 1
fi

# Check executable
if [ -f "/Applications/ParqView.app/Contents/MacOS/ParqView" ]; then
    echo -e "   ${GREEN}✓ Executable found${NC}"
else
    echo -e "   ${RED}✗ Executable not found${NC}"
fi

# Check Info.plist
if [ -f "/Applications/ParqView.app/Contents/Info.plist" ]; then
    echo -e "   ${GREEN}✓ Info.plist found${NC}"
else
    echo -e "   ${RED}✗ Info.plist not found${NC}"
fi

# Check icon
if [ -f "/Applications/ParqView.app/Contents/Resources/AppIcon.icns" ]; then
    echo -e "   ${GREEN}✓ Icon found${NC}"
else
    echo -e "   ${YELLOW}⚠ Icon not found (app will use default)${NC}"
fi

echo ""
echo "2. Checking file associations..."

# Check if parquet files are associated
HANDLER=$(/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -A 5 "\.parquet" | grep -c "ParqView")

if [ "$HANDLER" -gt 0 ]; then
    echo -e "   ${GREEN}✓ .parquet files associated with ParqView${NC}"
else
    echo -e "   ${YELLOW}⚠ .parquet files may not be associated${NC}"
fi

echo ""
echo "3. Testing app launch..."

# Kill any existing instances
killall ParqView 2>/dev/null || true
sleep 1

# Clear debug log
rm -f ~/parqview_debug.log

# Open the app
open /Applications/ParqView.app
sleep 2

# Check if running
if pgrep -x "ParqView" > /dev/null; then
    echo -e "   ${GREEN}✓ ParqView launched successfully${NC}"
else
    echo -e "   ${RED}✗ ParqView failed to launch${NC}"
fi

# Check debug log
if [ -f ~/parqview_debug.log ]; then
    if grep -q "ParqViewApp initialized" ~/parqview_debug.log; then
        echo -e "   ${GREEN}✓ App initialized properly${NC}"
    fi
fi

echo ""
echo "4. Testing file opening..."

if [ -f "medium_test_data.parquet" ]; then
    # Open a test file
    open medium_test_data.parquet
    sleep 3
    
    # Check if file was loaded
    if grep -q "File loaded successfully" ~/parqview_debug.log 2>/dev/null; then
        echo -e "   ${GREEN}✓ File opening works${NC}"
    else
        echo -e "   ${YELLOW}⚠ Could not verify file loading${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠ No test file available${NC}"
fi

echo ""
echo "==================================="
echo -e "${GREEN}Installation verification complete!${NC}"
echo ""
echo "You can now:"
echo "  • Double-click any .parquet file to open it"
echo "  • Right-click and choose 'Open With' > 'ParqView'"
echo "  • Drag .parquet files onto the app icon"
echo ""