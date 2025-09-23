#ifndef PARQUET_READER_H
#define PARQUET_READER_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char* name;
    char* type;
} ColumnInfo;

typedef struct {
    ColumnInfo* columns;
    int column_count;
    long long row_count;
} SchemaInfo;

typedef struct {
    char*** data;  // 2D array of strings
    int row_count;
    int column_count;
} TableData;

// Function declarations
SchemaInfo* read_parquet_schema(const char* file_path);
TableData* read_parquet_data(const char* file_path, int start_row, int num_rows);
void free_schema_info(SchemaInfo* info);
void free_table_data(TableData* data);
void clear_parquet_cache(const char* file_path);  // Clear cache for specific file
void clear_all_parquet_cache();  // Clear entire cache

#ifdef __cplusplus
}
#endif

#endif // PARQUET_READER_H