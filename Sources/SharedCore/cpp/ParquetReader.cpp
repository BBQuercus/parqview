#include "../include/ParquetReader.h"
#include <arrow/api.h>
#include <arrow/io/api.h>
#include <arrow/compute/api.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>
#include <parquet/metadata.h>
#include <iostream>
#include <memory>
#include <cstring>
#include <ctime>
#include <unordered_map>
#include <mutex>

// Global cache for open file readers to avoid repeated file opens
static std::unordered_map<std::string, std::unique_ptr<parquet::arrow::FileReader>> reader_cache;
static std::mutex cache_mutex;

extern "C" {

// Helper function to get or create a cached reader
std::unique_ptr<parquet::arrow::FileReader>* get_cached_reader(const char* file_path) {
    std::lock_guard<std::mutex> lock(cache_mutex);
    
    std::string path_str(file_path);
    auto it = reader_cache.find(path_str);
    
    if (it != reader_cache.end()) {
        return &(it->second);
    }
    
    // Create new reader
    try {
        // Use memory mapping for better performance
        std::shared_ptr<arrow::io::MemoryMappedFile> infile;
        auto result = arrow::io::MemoryMappedFile::Open(file_path, arrow::io::FileMode::READ);
        if (!result.ok()) {
            return nullptr;
        }
        infile = result.ValueOrDie();
        
        parquet::arrow::FileReaderBuilder builder;
        auto status = builder.Open(infile);
        if (!status.ok()) {
            return nullptr;
        }
        
        // Enable parallel column reading for better performance
        parquet::ArrowReaderProperties arrow_props;
        arrow_props.set_use_threads(true);
        arrow_props.set_batch_size(65536); // Larger batch size for better throughput
        builder.properties(arrow_props);
        
        std::unique_ptr<parquet::arrow::FileReader> reader;
        status = builder.Build(&reader);
        if (!status.ok()) {
            return nullptr;
        }
        
        reader_cache[path_str] = std::move(reader);
        return &reader_cache[path_str];
    } catch (...) {
        return nullptr;
    }
}

SchemaInfo* read_parquet_schema(const char* file_path) {
    try {
        auto reader_ptr = get_cached_reader(file_path);
        if (!reader_ptr || !(*reader_ptr)) {
            return nullptr;
        }
        auto& reader = *reader_ptr;

        std::shared_ptr<arrow::Schema> schema;
        auto status = reader->GetSchema(&schema);
        if (!status.ok()) {
            return nullptr;
        }

        auto* info = new SchemaInfo;
        info->column_count = schema->num_fields();
        info->row_count = reader->parquet_reader()->metadata()->num_rows();
        info->columns = new ColumnInfo[info->column_count];

        for (int i = 0; i < info->column_count; i++) {
            auto field = schema->field(i);
            info->columns[i].name = strdup(field->name().c_str());
            info->columns[i].type = strdup(field->type()->ToString().c_str());
        }

        return info;
    } catch (const std::exception& e) {
        std::cerr << "Error reading schema: " << e.what() << std::endl;
        return nullptr;
    }
}

TableData* read_parquet_data(const char* file_path, int start_row, int num_rows) {
    try {
        auto reader_ptr = get_cached_reader(file_path);
        if (!reader_ptr || !(*reader_ptr)) {
            return nullptr;
        }
        auto& reader = *reader_ptr;
        
        // Get metadata
        auto file_metadata = reader->parquet_reader()->metadata();
        int64_t total_rows = file_metadata->num_rows();
        int num_row_groups = file_metadata->num_row_groups();
        
        // Calculate actual rows to read
        int64_t end_row = std::min(static_cast<int64_t>(start_row + num_rows), total_rows);
        
        auto* data = new TableData;
        data->row_count = end_row - start_row;
        
        if (data->row_count <= 0) {
            data->column_count = 0;
            data->data = nullptr;
            return data;
        }
        
        // Find which row groups we need to read
        std::vector<int> row_groups_to_read;
        int64_t current_row = 0;
        
        for (int rg = 0; rg < num_row_groups; rg++) {
            int64_t rg_row_count = file_metadata->RowGroup(rg)->num_rows();
            
            // Check if this row group contains any rows we need
            if (current_row + rg_row_count > start_row && current_row < end_row) {
                row_groups_to_read.push_back(rg);
            }
            
            current_row += rg_row_count;
            
            // Stop if we've passed the end row
            if (current_row >= end_row) {
                break;
            }
        }
        
        // Read only the necessary row groups
        std::shared_ptr<arrow::Table> table;
        if (row_groups_to_read.size() == num_row_groups) {
            // If we need all row groups, just read the whole table
            auto status = reader->ReadTable(&table);
            if (!status.ok()) {
                delete data;
                return nullptr;
            }
        } else {
            // Read only selected row groups
            auto status = reader->ReadRowGroups(row_groups_to_read, &table);
            if (!status.ok()) {
                delete data;
                return nullptr;
            }
        }
        
        // Now slice the table to get exact range
        if (table->num_rows() > data->row_count) {
            // Calculate offset within the combined row groups
            int64_t offset_in_table = 0;
            current_row = 0;
            
            for (int rg : row_groups_to_read) {
                int64_t rg_row_count = file_metadata->RowGroup(rg)->num_rows();
                if (current_row + rg_row_count > start_row) {
                    offset_in_table = start_row - current_row;
                    break;
                }
                current_row += rg_row_count;
            }
            
            table = table->Slice(offset_in_table, data->row_count);
        }
        
        data->column_count = table->num_columns();
        
        // Allocate memory for data
        data->data = new char**[data->row_count];
        for (int i = 0; i < data->row_count; i++) {
            data->data[i] = new char*[data->column_count];
        }
        
        // Convert data to strings more efficiently
        for (int col = 0; col < data->column_count; col++) {
            auto column = table->column(col);
            
            // Process entire column at once
            int row_idx = 0;
            for (auto& chunk : column->chunks()) {
                for (int64_t i = 0; i < chunk->length() && row_idx < data->row_count; i++) {
                    std::string value;
                    
                    if (chunk->IsNull(i)) {
                        value = "NULL";
                    } else {
                        // Use visitor pattern for efficient type dispatch
                        switch (chunk->type_id()) {
                            case arrow::Type::STRING: {
                                auto array = std::static_pointer_cast<arrow::StringArray>(chunk);
                                value = std::string(array->GetView(i));
                                break;
                            }
                            case arrow::Type::INT64: {
                                auto array = std::static_pointer_cast<arrow::Int64Array>(chunk);
                                value = std::to_string(array->Value(i));
                                break;
                            }
                            case arrow::Type::INT32: {
                                auto array = std::static_pointer_cast<arrow::Int32Array>(chunk);
                                value = std::to_string(array->Value(i));
                                break;
                            }
                            case arrow::Type::DOUBLE: {
                                auto array = std::static_pointer_cast<arrow::DoubleArray>(chunk);
                                // Format double with limited precision
                                char buffer[32];
                                snprintf(buffer, sizeof(buffer), "%.6g", array->Value(i));
                                value = buffer;
                                break;
                            }
                            case arrow::Type::FLOAT: {
                                auto array = std::static_pointer_cast<arrow::FloatArray>(chunk);
                                char buffer[32];
                                snprintf(buffer, sizeof(buffer), "%.6g", array->Value(i));
                                value = buffer;
                                break;
                            }
                            case arrow::Type::BOOL: {
                                auto array = std::static_pointer_cast<arrow::BooleanArray>(chunk);
                                value = array->Value(i) ? "true" : "false";
                                break;
                            }
                            case arrow::Type::TIMESTAMP: {
                                auto array = std::static_pointer_cast<arrow::TimestampArray>(chunk);
                                // Convert timestamp to ISO string
                                auto timestamp = array->Value(i);
                                // Timestamps are usually in microseconds or milliseconds
                                time_t seconds = timestamp / 1000000;  // Assuming microseconds
                                auto tm = *std::gmtime(&seconds);
                                char buffer[64];
                                strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", &tm);
                                value = buffer;
                                break;
                            }
                            case arrow::Type::DATE32: {
                                auto array = std::static_pointer_cast<arrow::Date32Array>(chunk);
                                // Date32 is days since epoch
                                auto days = array->Value(i);
                                time_t seconds = days * 86400;
                                auto tm = *std::gmtime(&seconds);
                                char buffer[32];
                                strftime(buffer, sizeof(buffer), "%Y-%m-%d", &tm);
                                value = buffer;
                                break;
                            }
                            case arrow::Type::DATE64: {
                                auto array = std::static_pointer_cast<arrow::Date64Array>(chunk);
                                // Date64 is milliseconds since epoch
                                auto millis = array->Value(i);
                                time_t seconds = millis / 1000;
                                auto tm = *std::gmtime(&seconds);
                                char buffer[32];
                                strftime(buffer, sizeof(buffer), "%Y-%m-%d", &tm);
                                value = buffer;
                                break;
                            }
                            default:
                                // For unsupported types, try to get string representation
                                value = "UNSUPPORTED";
                                break;
                        }
                    }
                    
                    data->data[row_idx][col] = strdup(value.c_str());
                    row_idx++;
                }
            }
        }
        
        return data;
    } catch (const std::exception& e) {
        std::cerr << "Error reading data: " << e.what() << std::endl;
        return nullptr;
    }
}

void free_schema_info(SchemaInfo* info) {
    if (info) {
        for (int i = 0; i < info->column_count; i++) {
            free(info->columns[i].name);
            free(info->columns[i].type);
        }
        delete[] info->columns;
        delete info;
    }
}

void free_table_data(TableData* data) {
    if (data) {
        if (data->data) {
            for (int i = 0; i < data->row_count; i++) {
                for (int j = 0; j < data->column_count; j++) {
                    free(data->data[i][j]);
                }
                delete[] data->data[i];
            }
            delete[] data->data;
        }
        delete data;
    }
}

void clear_parquet_cache(const char* file_path) {
    std::lock_guard<std::mutex> lock(cache_mutex);
    std::string path_str(file_path);
    reader_cache.erase(path_str);
}

void clear_all_parquet_cache() {
    std::lock_guard<std::mutex> lock(cache_mutex);
    reader_cache.clear();
}

} // extern "C"