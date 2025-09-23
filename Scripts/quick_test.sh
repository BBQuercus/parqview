#!/bin/bash

# Quick test to verify ParqView file opening

echo "Quick ParqView File Opening Test"
echo "================================="
echo ""

# First, let's create a simple test parquet file using Python if available
if command -v python3 &> /dev/null; then
    echo "Creating test parquet file..."
    python3 << 'EOF'
import sys
try:
    import pandas as pd
    import pyarrow as pa
    import pyarrow.parquet as pq
    
    # Create simple test data
    data = {
        'id': [1, 2, 3, 4, 5],
        'name': ['Alice', 'Bob', 'Charlie', 'David', 'Eve'],
        'value': [100.5, 200.7, 150.3, 175.9, 225.1]
    }
    df = pd.DataFrame(data)
    df.to_parquet('simple_test.parquet')
    print("✓ Created simple_test.parquet")
except ImportError as e:
    print(f"Missing Python library: {e}")
    print("Please install: pip install pandas pyarrow")
    sys.exit(1)
EOF
    
    if [ $? -ne 0 ]; then
        echo "Failed to create test file. Using existing file if available."
    fi
fi

# Now test opening the file
if [ -f "simple_test.parquet" ]; then
    echo ""
    echo "Opening simple_test.parquet with ParqView..."
    
    # Get absolute path
    TEST_FILE=$(pwd)/simple_test.parquet
    echo "File path: $TEST_FILE"
    
    # Open with explicit app path and capture any output
    open -a /Applications/ParqView.app "$TEST_FILE"
    
    echo ""
    echo "✓ Command sent to open file"
    echo ""
    echo "Please check if ParqView opened and loaded the file."
    echo "Look for the file data displayed in the ParqView window."
    
else
    echo "No test file available. Please provide a .parquet file."
fi