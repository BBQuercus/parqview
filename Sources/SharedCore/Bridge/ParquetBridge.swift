import Foundation
import CParquetReader

/// Swift bridge to C++ Parquet/Arrow functionality
/// This class wraps the C++ implementation to provide a Swift-friendly API
public class ParquetBridge {
    
    /// Singleton instance for shared functionality
    public static let shared = ParquetBridge()
    
    /// Cache for schema to avoid repeated C++ calls (C++ handles file caching internally)
    private var schemaCache: [URL: ParquetSchema] = [:]

    /// Cached date formatter for performance
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
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
            return .decimal
        } else {
            return .string  // Default fallback
        }
    }

    private func convertValue(_ valueStr: String, to type: ParquetType) -> ParquetValue {
        switch type {
        case .boolean:
            return .bool(valueStr.lowercased() == "true" || valueStr == "1")
        case .int32, .int64, .int96:
            if let intVal = Int64(valueStr) {
                return .int(intVal)
            }
            // Try parsing as double first (handles scientific notation)
            if let doubleVal = Double(valueStr), doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                return .int(Int64(doubleVal))
            }
            return .string(valueStr)
        case .float, .double, .decimal:
            if let floatVal = Double(valueStr) {
                return .float(floatVal)
            }
            return .string(valueStr)
        case .date, .timestamp:
            if let date = Self.isoFormatter.date(from: valueStr) {
                return type == .date ? .date(date) : .timestamp(date)
            }
            // Try alternative date formats
            if let date = parseFlexibleDate(valueStr) {
                return type == .date ? .date(date) : .timestamp(date)
            }
            return .string(valueStr)
        case .binary, .fixedLenByteArray:
            if let data = Data(base64Encoded: valueStr) {
                return .binary(data)
            }
            return .string(valueStr)
        default:
            return .string(valueStr)
        }
    }

    private func parseFlexibleDate(_ str: String) -> Date? {
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: str) {
                return date
            }
        }
        return nil
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
        let rowCount = Int(tableData.pointee.row_count)
        let colCount = Int(tableData.pointee.column_count)

        for rowIdx in 0..<rowCount {
            var values: [ParquetValue] = []

            // Bounds check: ensure row pointer exists
            guard let rowPtr = tableData.pointee.data[rowIdx] else {
                continue
            }

            for colIdx in 0..<colCount {
                // Bounds check: ensure column pointer exists
                guard let valuePtr = rowPtr[colIdx] else {
                    values.append(.null)
                    continue
                }

                let valueStr = String(cString: valuePtr)

                // Convert based on schema type if available
                let columnType = colIdx < schema.columns.count ? schema.columns[colIdx].type : .string

                if valueStr == "NULL" || valueStr.isEmpty {
                    values.append(.null)
                } else {
                    values.append(convertValue(valueStr, to: columnType))
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