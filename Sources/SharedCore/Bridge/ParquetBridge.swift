import Foundation
import CParquetReader

/// Swift bridge to C++ Parquet/Arrow functionality
/// This class wraps the C++ implementation to provide a Swift-friendly API
public class ParquetBridge {
    
    /// Singleton instance for shared functionality
    public static let shared = ParquetBridge()
    
    /// Cache for schema to avoid repeated C++ calls (C++ handles file caching internally)
    private var schemaCache: [URL: ParquetSchema] = [:]
    
    private init() {
        // C++ components initialized on first use
    }
    
    deinit {
        // Clear C++ cache on deallocation
        clear_all_parquet_cache()
    }
    
    // MARK: - Schema Reading
    
    /// Reads just the schema from a Parquet file without loading data
    /// This is very fast as it only reads metadata
    public func readSchema(from url: URL) throws -> ParquetSchema {
        // Check cache first
        if let cached = schemaCache[url] {
            return cached
        }
        
        // Read schema using C++ implementation
        guard let schemaInfo = read_parquet_schema(url.path) else {
            throw ParquetError.invalidSchema
        }
        defer { free_schema_info(schemaInfo) }
        
        // Convert C schema to Swift schema
        var columns: [SchemaColumn] = []
        for i in 0..<Int(schemaInfo.pointee.column_count) {
            let colInfo = schemaInfo.pointee.columns[i]
            let name = String(cString: colInfo.name)
            let typeStr = String(cString: colInfo.type)
            
            columns.append(SchemaColumn(
                name: name,
                type: convertArrowType(typeStr),
                isNullable: true  // Arrow types are generally nullable
            ))
        }
        
        let schema = ParquetSchema(columns: columns)
        
        // Cache the schema
        schemaCache[url] = schema
        
        if schema.columns.isEmpty {
            throw ParquetError.invalidSchema
        }
        
        return schema
    }
    
    private func convertArrowType(_ arrowType: String) -> ParquetType {
        let type = arrowType.lowercased()
        
        // Handle Arrow C++ type strings
        if type.contains("bool") {
            return .boolean
        } else if type.contains("int64") {
            return .int64
        } else if type.contains("int32") {
            return .int32
        } else if type.contains("int96") {
            return .int96
        } else if type.contains("float") && !type.contains("double") {
            return .float
        } else if type.contains("double") || type.contains("float64") {
            return .double
        } else if type.contains("string") || type.contains("utf8") || type.contains("large_string") {
            return .string
        } else if type.contains("binary") || type.contains("fixed_size_binary") {
            return .binary
        } else if type.contains("date") {
            return .date
        } else if type.contains("timestamp") {
            return .timestamp
        } else if type.contains("decimal") {
            return .double  // Treat decimal as double for now
        } else {
            return .string  // Default fallback
        }
    }
    
    // MARK: - Data Sampling
    
    /// Reads the first N rows from a Parquet file
    /// Used for initial display and data preview
    public func readSampleRows(from url: URL, limit: Int = 100, offset: Int = 0) throws -> [ParquetRow] {
        let startTime = Date()
        
        // Read data using C++ implementation
        guard let tableData = read_parquet_data(url.path, Int32(offset), Int32(limit)) else {
            throw ParquetError.dataReadError
        }
        defer { free_table_data(tableData) }
        
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 0.5 {
            print("⏱️ Data read took \(String(format: "%.2f", elapsed)) seconds")
        }
        
        // Get schema for proper type conversion
        let schema = try readSchema(from: url)
        
        // Convert C data to Swift rows
        var rows: [ParquetRow] = []
        
        for rowIdx in 0..<Int(tableData.pointee.row_count) {
            var values: [ParquetValue] = []
            
            for colIdx in 0..<Int(tableData.pointee.column_count) {
                // Get the string value from C array
                let valuePtr = tableData.pointee.data[rowIdx]![colIdx]!
                let valueStr = String(cString: valuePtr)
                
                // Convert based on schema type if available
                let columnType = colIdx < schema.columns.count ? schema.columns[colIdx].type : .string
                
                if valueStr == "NULL" {
                    values.append(.null)
                } else {
                    switch columnType {
                    case .boolean:
                        values.append(.bool(valueStr == "true"))
                    case .int32, .int64, .int96:
                        if let intVal = Int64(valueStr) {
                            values.append(.int(intVal))
                        } else {
                            values.append(.string(valueStr))
                        }
                    case .float, .double:
                        if let floatVal = Double(valueStr) {
                            values.append(.float(floatVal))
                        } else {
                            values.append(.string(valueStr))
                        }
                    case .string, .binary, .fixedLenByteArray:
                        values.append(.string(valueStr))
                    case .date, .timestamp:
                        // Try to parse as date
                        let formatter = ISO8601DateFormatter()
                        if let date = formatter.date(from: valueStr) {
                            values.append(.timestamp(date))
                        } else {
                            values.append(.string(valueStr))
                        }
                    default:
                        // Handle all other types as strings
                        values.append(.string(valueStr))
                    }
                }
            }
            
            if !values.isEmpty {
                rows.append(ParquetRow(values: values))
            }
        }
        
        return rows
    }
    
    // MARK: - Metadata
    
    /// Reads file metadata without loading data
    public func readMetadata(from url: URL) throws -> ParquetMetadata {
        // For now, return basic metadata from schema
        // In a full implementation, we'd add more C++ functions for detailed metadata
        let _ = try readSchema(from: url)
        
        return ParquetMetadata(
            createdBy: "Unknown",
            version: "Unknown",
            rowGroups: 1,  // Would need C++ function to get this
            compressionCodec: "Unknown"
        )
    }
    
    /// Gets the total row count without loading data
    public func getRowCount(from url: URL) throws -> Int {
        // Read schema which includes row count
        guard let schemaInfo = read_parquet_schema(url.path) else {
            throw ParquetError.invalidMetadata
        }
        defer { free_schema_info(schemaInfo) }
        
        return Int(schemaInfo.pointee.row_count)
    }
    
    /// Clear cached metadata for a file
    public func clearCache(for url: URL) {
        schemaCache.removeValue(forKey: url)
        // Also clear C++ cache for this file
        clear_parquet_cache(url.path)
    }
    
    /// Clear all cached metadata
    public func clearAllCache() {
        schemaCache.removeAll()
        // Clear all C++ caches
        clear_all_parquet_cache()
    }
}