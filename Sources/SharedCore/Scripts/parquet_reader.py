#!/usr/bin/env python3
import sys
import json
import struct
import os

def read_parquet_metadata(file_path):
    """Read basic metadata from a parquet file without external dependencies"""
    try:
        with open(file_path, 'rb') as f:
            # Read file size
            f.seek(0, 2)  # Seek to end
            file_size = f.tell()
            
            # Parquet files have "PAR1" magic bytes at start and end
            f.seek(0)
            magic_start = f.read(4)
            
            if magic_start != b'PAR1':
                return {"error": "Not a valid Parquet file"}
            
            # Footer is at the end, read last 8 bytes to get footer length
            f.seek(-8, 2)
            footer_length = struct.unpack('<I', f.read(4))[0]
            magic_end = f.read(4)
            
            if magic_end != b'PAR1':
                return {"error": "Invalid Parquet file footer"}
            
            # Read the footer metadata
            f.seek(-(8 + footer_length), 2)
            footer_bytes = f.read(footer_length)
            
            # Try to parse with pyarrow if available
            try:
                import pyarrow.parquet as pq
                
                # Read the actual file
                parquet_file = pq.ParquetFile(file_path)
                metadata = parquet_file.metadata
                schema = parquet_file.schema
                
                # Get column information
                columns = []
                for i in range(len(schema)):
                    field = schema[i]
                    columns.append({
                        "name": field.name,
                        "type": str(field.physical_type) if hasattr(field, 'physical_type') else str(field),
                        "nullable": True  # Parquet schema doesn't have nullable info directly
                    })
                
                return {
                    "num_rows": metadata.num_rows,
                    "num_columns": len(schema),
                    "columns": columns,
                    "num_row_groups": metadata.num_row_groups,
                    "created_by": metadata.created_by if metadata.created_by else "Unknown",
                    "format_version": metadata.format_version
                }
                
            except ImportError:
                # Fallback: try pandas
                try:
                    import pandas as pd
                    
                    # Try to use pyarrow engine directly if available
                    try:
                        # This should work if pyarrow is installed
                        import pyarrow.parquet as pq
                        pf = pq.ParquetFile(file_path)
                        
                        # Get metadata without reading data
                        metadata = pf.metadata
                        schema = pf.schema
                        
                        columns = []
                        for field in schema:
                            columns.append({
                                "name": field.name,
                                "type": str(field.type),
                                "nullable": True
                            })
                        
                        return {
                            "num_rows": metadata.num_rows,
                            "num_columns": len(schema),
                            "columns": columns,
                            "num_row_groups": metadata.num_row_groups,
                            "created_by": "Unknown",
                            "format_version": "Unknown"
                        }
                    except ImportError:
                        # Last resort: read with pandas (slow)
                        df = pd.read_parquet(file_path)
                        
                        columns = []
                        for col in df.columns:
                            dtype = str(df[col].dtype)
                            columns.append({
                                "name": col,
                                "type": dtype,
                                "nullable": df[col].isnull().any()
                            })
                        
                        return {
                            "num_rows": len(df),
                            "num_columns": len(df.columns),
                            "columns": columns,
                            "num_row_groups": 1,
                            "created_by": "Unknown",
                            "format_version": "Unknown"
                        }
                    
                except ImportError:
                    # No libraries available, return basic info
                    return {
                        "error": "No Parquet libraries available (install pyarrow or pandas)",
                        "file_size": file_size,
                        "is_parquet": True
                    }
            
    except Exception as e:
        return {"error": str(e)}

def read_parquet_data(file_path, offset=0, limit=100):
    """Read actual data from a parquet file"""
    try:
        # Try pyarrow first
        try:
            import pyarrow.parquet as pq
            
            # Open the file without reading all data
            parquet_file = pq.ParquetFile(file_path)
            total_rows = parquet_file.metadata.num_rows
            
            # Calculate which row groups to read
            if offset >= total_rows:
                return {"rows": [], "total_rows": total_rows}
            
            # For small limits, read only what we need using row groups
            # This avoids loading the entire file into memory
            rows = []
            current_row = 0
            end_row = min(offset + limit, total_rows)
            
            for i in range(parquet_file.num_row_groups):
                row_group = parquet_file.metadata.row_group(i)
                group_rows = row_group.num_rows
                
                # Skip row groups before our offset
                if current_row + group_rows <= offset:
                    current_row += group_rows
                    continue
                
                # Stop if we've passed our end row
                if current_row >= end_row:
                    break
                
                # Read this row group
                table = parquet_file.read_row_group(i)
                
                # Calculate slice within this row group
                start_in_group = max(0, offset - current_row)
                end_in_group = min(group_rows, end_row - current_row)
                
                if start_in_group < end_in_group:
                    slice_table = table.slice(start_in_group, end_in_group - start_in_group)
                    
                    # Convert to list of rows
                    for j in range(len(slice_table)):
                        row = []
                        for col in slice_table.column_names:
                            value = slice_table[col][j].as_py()
                            if value is None:
                                row.append({"type": "null", "value": None})
                            elif isinstance(value, bool):
                                row.append({"type": "bool", "value": value})
                            elif isinstance(value, int):
                                row.append({"type": "int", "value": value})
                            elif isinstance(value, float):
                                row.append({"type": "float", "value": value})
                            else:
                                row.append({"type": "string", "value": str(value)})
                        rows.append(row)
                
                current_row += group_rows
            
            return {"rows": rows, "total_rows": total_rows}
            
        except ImportError:
            # Fallback to pandas - still need to read entire file with pandas
            # but at least only process the slice we need
            try:
                import pandas as pd
                import numpy as np
                
                # For metadata, we need to read just enough to get total rows
                # We can't avoid this with pandas unfortunately
                parquet_file = pd.read_parquet(file_path, engine='pyarrow' if 'pyarrow' in sys.modules else 'fastparquet')
                total_rows = len(parquet_file)
                
                # Get the slice we need
                end = min(offset + limit, total_rows)
                if offset >= total_rows:
                    return {"rows": [], "total_rows": total_rows}
                
                df_slice = parquet_file.iloc[offset:end]
                
                # Convert to list of rows
                rows = []
                for _, row in df_slice.iterrows():
                    row_data = []
                    for value in row:
                        if pd.isna(value):
                            row_data.append({"type": "null", "value": None})
                        elif isinstance(value, bool):
                            row_data.append({"type": "bool", "value": value})
                        elif isinstance(value, (int, np.integer)):
                            row_data.append({"type": "int", "value": int(value)})
                        elif isinstance(value, (float, np.floating)):
                            row_data.append({"type": "float", "value": float(value)})
                        else:
                            row_data.append({"type": "string", "value": str(value)})
                    rows.append(row_data)
                
                return {"rows": rows, "total_rows": total_rows}
                
            except ImportError:
                return {"error": "No Parquet libraries available (install pyarrow or pandas)"}
            except Exception as e:
                return {"error": f"pandas error: {str(e)}"}
                
    except Exception as e:
        return {"error": str(e)}

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: parquet_reader.py <command> <file_path> [offset] [limit]"}))
        sys.exit(1)
    
    command = sys.argv[1]
    file_path = sys.argv[2]
    
    if not os.path.exists(file_path):
        print(json.dumps({"error": f"File not found: {file_path}"}))
        sys.exit(1)
    
    if command == "metadata":
        result = read_parquet_metadata(file_path)
        print(json.dumps(result))
    
    elif command == "read":
        offset = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        limit = int(sys.argv[4]) if len(sys.argv) > 4 else 100
        result = read_parquet_data(file_path, offset, limit)
        print(json.dumps(result))
    
    else:
        print(json.dumps({"error": f"Unknown command: {command}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()