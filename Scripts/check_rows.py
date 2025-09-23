import duckdb

conn = duckdb.connect()
result = conn.execute("SELECT COUNT(*) FROM './Tests/data.parquet'").fetchone()
print(f"Actual row count: {result[0]}")

# Also show first few rows to understand the data
print("\nFirst 5 rows:")
rows = conn.execute("SELECT * FROM './Tests/data.parquet' LIMIT 5").fetchall()
for row in rows:
    print(row)
