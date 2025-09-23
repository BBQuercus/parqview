#!/bin/bash

# ParqView Test Script
# This script helps test ParqView with sample files and debugging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ParqView Test Script ===${NC}"
echo ""

# Function to create a test parquet file
create_test_file() {
    echo -e "${YELLOW}Creating test Parquet file...${NC}"
    
    # Create a simple Python script to generate a test parquet file
    cat > create_test_parquet.py << 'EOF'
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Create sample data
data = {
    'id': range(1, 101),
    'name': [f'Person_{i}' for i in range(1, 101)],
    'age': np.random.randint(18, 80, 100),
    'salary': np.random.uniform(30000, 150000, 100).round(2),
    'department': np.random.choice(['Sales', 'Engineering', 'Marketing', 'HR', 'Finance'], 100),
    'hire_date': [datetime.now() - timedelta(days=np.random.randint(0, 3650)) for _ in range(100)],
    'is_active': np.random.choice([True, False], 100, p=[0.85, 0.15])
}

df = pd.DataFrame(data)
df.to_parquet('test_data.parquet', engine='pyarrow')
print("Created test_data.parquet with 100 rows and 7 columns")
EOF
    
    # Check if Python and required libraries are available
    if command -v python3 &> /dev/null && python3 -c "import pandas, pyarrow" 2>/dev/null; then
        python3 create_test_parquet.py
        rm create_test_parquet.py
        echo -e "${GREEN}✓ Test file created: test_data.parquet${NC}"
    else
        echo -e "${YELLOW}Note: Python with pandas and pyarrow not found. Please provide your own .parquet file.${NC}"
    fi
    echo ""
}

# Function to run the app with console output
run_with_console() {
    echo -e "${BLUE}Running ParqView with console output...${NC}"
    echo -e "${YELLOW}Watch for debug messages prefixed with icons:${NC}"
    echo "  🚀 = App initialization"
    echo "  📂 = File URL received from Finder"
    echo "  🔄 = File loading started"
    echo "  ✅ = Success messages"
    echo "  ❌ = Error messages"
    echo "  🎨 = UI rendering"
    echo "  🏁 = Loading completed"
    echo ""
    
    if [ -f "/Applications/ParqView.app/Contents/MacOS/ParqView" ]; then
        echo "Starting ParqView from /Applications..."
        /Applications/ParqView.app/Contents/MacOS/ParqView
    else
        echo "ParqView not found in /Applications. Running from build directory..."
        swift run ParqViewApp
    fi
}

# Function to test file opening
test_file_open() {
    local file="$1"
    
    if [ -z "$file" ]; then
        if [ -f "test_data.parquet" ]; then
            file="test_data.parquet"
        else
            echo -e "${RED}No file specified and test_data.parquet not found${NC}"
            return 1
        fi
    fi
    
    echo -e "${BLUE}Testing file open with: $file${NC}"
    
    # Get absolute path
    file=$(realpath "$file")
    
    echo "Opening file: $file"
    echo ""
    
    # Open the file with ParqView
    open -a ParqView "$file" 2>&1 &
    
    echo -e "${GREEN}File open command sent${NC}"
    echo "Check if ParqView opened and loaded the file correctly."
    echo ""
}

# Main menu
echo "Select test option:"
echo "  1) Build and install ParqView first"
echo "  2) Run ParqView with console output"
echo "  3) Create test Parquet file"
echo "  4) Test opening a Parquet file"
echo "  5) Full test (create file + open)"
echo "  6) Check current installations"
echo ""
read -p "Enter option (1-6): " option

case $option in
    1)
        echo -e "${YELLOW}Running build and install script...${NC}"
        ./build_and_install.sh
        ;;
    2)
        run_with_console
        ;;
    3)
        create_test_file
        ;;
    4)
        read -p "Enter path to .parquet file (or press Enter for test file): " filepath
        test_file_open "$filepath"
        ;;
    5)
        create_test_file
        if [ -f "test_data.parquet" ]; then
            test_file_open "test_data.parquet"
        fi
        ;;
    6)
        echo -e "${YELLOW}Checking for ParqView installations...${NC}"
        echo ""
        
        if [ -f "/Applications/ParqView.app/Contents/MacOS/ParqView" ]; then
            echo -e "${GREEN}✓ Found in /Applications/ParqView.app${NC}"
            echo "  Version info:"
            /Applications/ParqView.app/Contents/MacOS/ParqView --version 2>/dev/null || echo "  (no version info available)"
        else
            echo "✗ Not found in /Applications"
        fi
        
        if [ -f "$HOME/Applications/ParqView.app/Contents/MacOS/ParqView" ]; then
            echo -e "${GREEN}✓ Found in ~/Applications/ParqView.app${NC}"
        fi
        
        echo ""
        echo "Checking Launch Services registration..."
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -i parqview | head -5 || echo "Not found in Launch Services"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac