#\!/usr/bin/env python3
import sys
import json

# Try with pandas first, then fall back to pyarrow
try:
    import pandas as pd
    df = pd.read_parquet('./Tests/data.parquet')
    print(f"Actual rows: {len(df)}")
    print(f"Columns: {list(df.columns)}")
    print("\nFirst 3 rows:")
    print(df.head(3).to_string())
except ImportError:
    print("pandas not available, trying manual inspection...")
    # Try to read the file directly
    with open('./Tests/data.parquet', 'rb') as f:
        data = f.read()
        # Look for PAR1 magic bytes
        if data[:4] == b'PAR1':
            print("This is a valid Parquet file")
            # The actual row count would be in the metadata, but it's hard to parse manually
            print("File size:", len(data), "bytes")
