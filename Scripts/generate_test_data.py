#!/usr/bin/env python3

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import string
import pyarrow as pa
import pyarrow.parquet as pq

def generate_large_parquet(filename="large_test_data.parquet", num_rows=1_000_000):
    """
    Generate a large parquet file with various data types for testing.
    
    Args:
        filename: Output filename
        num_rows: Number of rows to generate (default 1 million)
    """
    print(f"Generating {num_rows:,} rows of test data...")
    
    # Set random seed for reproducibility
    np.random.seed(42)
    random.seed(42)
    
    # Generate various types of data
    data = {
        # Numeric columns
        'id': np.arange(1, num_rows + 1),
        'integer_col': np.random.randint(-1000, 1000, num_rows),
        'bigint_col': np.random.randint(-2**31, 2**31, num_rows, dtype=np.int64),
        'float_col': np.random.randn(num_rows) * 100,
        'double_col': np.random.randn(num_rows) * 1000,
        'decimal_col': np.round(np.random.randn(num_rows) * 10000, 2),
        
        # Boolean column
        'boolean_col': np.random.choice([True, False], num_rows),
        
        # String columns
        'name': [f"Person_{i}" for i in range(num_rows)],
        'email': [f"user{i}@example{i%100}.com" for i in range(num_rows)],
        'category': np.random.choice(['A', 'B', 'C', 'D', 'E'], num_rows),
        'status': np.random.choice(['active', 'inactive', 'pending', 'suspended'], num_rows),
        
        # Date and timestamp columns
        'date_col': pd.date_range(start='2020-01-01', periods=num_rows, freq='1min')[:num_rows],
        'timestamp_col': pd.date_range(start='2020-01-01', periods=num_rows, freq='1s')[:num_rows],
        
        # Nullable columns (with some nulls)
        'nullable_int': np.where(
            np.random.random(num_rows) > 0.1,
            np.random.randint(0, 1000, num_rows),
            np.nan
        ),
        'nullable_string': [
            ''.join(random.choices(string.ascii_letters, k=10)) 
            if random.random() > 0.05 else None 
            for _ in range(num_rows)
        ],
        
        # JSON-like column (stored as string)
        'metadata': [
            f'{{"key{i%10}": "value{i}", "score": {random.random():.2f}}}'
            for i in range(num_rows)
        ],
        
        # Binary data column (small random bytes)
        'binary_col': [bytes(np.random.bytes(16)) for _ in range(num_rows)],
        
        # Array/list column (PyArrow supports nested types)
        'tags': [
            random.sample(['tag1', 'tag2', 'tag3', 'tag4', 'tag5', 'tag6', 'tag7', 'tag8'], 
                         k=random.randint(1, 4))
            for _ in range(num_rows)
        ],
        
        # Numeric arrays
        'scores': [np.random.randint(0, 100, size=5).tolist() for _ in range(num_rows)],
        
        # Geographic-like data
        'latitude': np.random.uniform(-90, 90, num_rows),
        'longitude': np.random.uniform(-180, 180, num_rows),
        
        # Financial-like data
        'amount': np.round(np.random.uniform(0.01, 10000, num_rows), 2),
        'currency': np.random.choice(['USD', 'EUR', 'GBP', 'JPY', 'CNY'], num_rows),
        
        # Percentage/ratio data
        'completion_rate': np.random.uniform(0, 1, num_rows),
        'score_percentile': np.random.uniform(0, 100, num_rows),
    }
    
    # Create DataFrame
    print("Creating DataFrame...")
    df = pd.DataFrame(data)
    
    # Add some computed columns
    df['amount_usd'] = df.apply(
        lambda row: row['amount'] * {'USD': 1, 'EUR': 1.1, 'GBP': 1.3, 'JPY': 0.0067, 'CNY': 0.14}[row['currency']], 
        axis=1
    )
    df['is_premium'] = df['amount_usd'] > 5000
    df['days_since_start'] = (df['date_col'] - df['date_col'].min()).dt.days
    
    # Create a complex nested structure
    print("Adding nested structures...")
    df['user_profile'] = df.apply(
        lambda row: {
            'id': row['id'],
            'name': row['name'],
            'email': row['email'],
            'premium': row['is_premium'],
            'location': {
                'lat': row['latitude'],
                'lon': row['longitude']
            }
        },
        axis=1
    )
    
    # Convert to PyArrow Table for more control over schema
    print("Converting to PyArrow Table...")
    table = pa.Table.from_pandas(df)
    
    # Write to Parquet with compression
    print(f"Writing to {filename} with snappy compression...")
    pq.write_table(
        table,
        filename,
        compression='snappy',
        row_group_size=50000,  # Create multiple row groups for testing
    )
    
    # Calculate and display file statistics
    file_size = os.path.getsize(filename)
    print(f"\n✅ Successfully created {filename}")
    print(f"   Rows: {num_rows:,}")
    print(f"   Columns: {len(df.columns)}")
    print(f"   File size: {file_size / (1024**2):.2f} MB")
    print(f"   Compression: snappy")
    print(f"   Row groups: {num_rows // 50000 + (1 if num_rows % 50000 else 0)}")
    
    # Display schema
    print("\nSchema:")
    for field in table.schema:
        print(f"   {field.name}: {field.type}")
    
    return filename

if __name__ == "__main__":
    import os
    import sys
    
    # Parse command line arguments
    if len(sys.argv) > 1:
        try:
            num_rows = int(sys.argv[1])
        except ValueError:
            print(f"Error: Invalid number of rows '{sys.argv[1]}'")
            print("Usage: python generate_test_data.py [num_rows]")
            sys.exit(1)
    else:
        num_rows = 1_000_000
    
    filename = "large_test_data.parquet"
    if len(sys.argv) > 2:
        filename = sys.argv[2]
    
    generate_large_parquet(filename, num_rows)