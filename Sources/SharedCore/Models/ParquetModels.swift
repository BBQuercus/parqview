import Foundation

// MARK: - Schema Types

/// Represents a Parquet file's schema
public struct ParquetSchema: Codable, Equatable {
    public let columns: [SchemaColumn]
    
    public init(columns: [SchemaColumn]) {
        self.columns = columns
    }
}

/// Represents a single column in the schema
public struct SchemaColumn: Identifiable, Codable, Hashable {
    public let id = UUID()
    public let name: String
    public let type: ParquetType
    public let isNullable: Bool
    
    public init(name: String, type: ParquetType, isNullable: Bool) {
        self.name = name
        self.type = type
        self.isNullable = isNullable
    }
}

/// Parquet data types
/// These map to the logical types in the Parquet specification
public enum ParquetType: String, Codable, CustomStringConvertible {
    case boolean = "BOOLEAN"
    case int32 = "INT32"
    case int64 = "INT64"
    case int96 = "INT96"  // Deprecated but still found in some files
    case float = "FLOAT"
    case double = "DOUBLE"
    case byteArray = "BYTE_ARRAY"
    case fixedLenByteArray = "FIXED_LEN_BYTE_ARRAY"
    
    // Logical types
    case string = "STRING"
    case date = "DATE"
    case timestamp = "TIMESTAMP"
    case time = "TIME"
    case decimal = "DECIMAL"
    case uuid = "UUID"
    case json = "JSON"
    case binary = "BINARY"
    case list = "LIST"
    case map = "MAP"
    case structure = "STRUCT"
    
    public var description: String {
        switch self {
        case .boolean: return "Boolean"
        case .int32: return "Int32"
        case .int64: return "Int64"
        case .int96: return "Int96"
        case .float: return "Float"
        case .double: return "Double"
        case .string: return "String"
        case .date: return "Date"
        case .timestamp: return "Timestamp"
        case .time: return "Time"
        case .decimal: return "Decimal"
        case .uuid: return "UUID"
        case .json: return "JSON"
        case .binary: return "Binary"
        case .list: return "List"
        case .map: return "Map"
        case .structure: return "Struct"
        case .byteArray: return "Byte Array"
        case .fixedLenByteArray: return "Fixed Byte Array"
        }
    }

    /// Short type description for compact display
    public var shortDescription: String {
        switch self {
        case .boolean: return "bool"
        case .int32: return "i32"
        case .int64: return "i64"
        case .int96: return "i96"
        case .float: return "f32"
        case .double: return "f64"
        case .string: return "str"
        case .date: return "date"
        case .timestamp: return "ts"
        case .time: return "time"
        case .decimal: return "dec"
        case .uuid: return "uuid"
        case .json: return "json"
        case .binary: return "bin"
        case .list: return "list"
        case .map: return "map"
        case .structure: return "struct"
        case .byteArray: return "bytes"
        case .fixedLenByteArray: return "fbytes"
        }
    }
}

// MARK: - Data Types

/// Represents a single row of data from a Parquet file
public struct ParquetRow: Identifiable {
    public let id = UUID()
    public let values: [ParquetValue]
    
    public init(values: [ParquetValue]) {
        self.values = values
    }
}

/// Represents a single value in a Parquet file
/// Using an enum allows us to preserve type information
public enum ParquetValue: Codable {
    case null
    case bool(Bool)
    case int(Int64)
    case float(Double)
    case string(String)
    case binary(Data)
    case date(Date)
    case timestamp(Date)
    
    // Helper for display
    public var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }
}

// MARK: - File Representation

/// Represents an opened Parquet file
public struct ParquetFile: Equatable, Identifiable {
    public let id = UUID()  // Unique ID for each file instance
    public let name: String
    public let url: URL
    public let sizeInBytes: Int64
    public let schema: ParquetSchema
    public let totalRows: Int
    public let metadata: ParquetMetadata?
    
    public init(name: String, url: URL, sizeInBytes: Int64, schema: ParquetSchema, totalRows: Int, metadata: ParquetMetadata? = nil) {
        self.name = name
        self.url = url
        self.sizeInBytes = sizeInBytes
        self.schema = schema
        self.totalRows = totalRows
        self.metadata = metadata
    }
    
    /// Loads a Parquet file from the given URL
    /// This uses the C++ Arrow/Parquet library via ParquetBridge
    public static func load(from url: URL) async throws -> ParquetFile {
        // Use the real ParquetBridge to read the file
        let bridge = ParquetBridge.shared
        
        // Get file info
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeInBytes = fileAttributes[.size] as? Int64 ?? 0
        let fileName = url.lastPathComponent
        
        // Read schema and metadata
        let schema = try bridge.readSchema(from: url)
        let totalRows = try bridge.getRowCount(from: url)
        let metadata = try bridge.readMetadata(from: url)
        
        return ParquetFile(
            name: fileName,
            url: url,
            sizeInBytes: sizeInBytes,
            schema: schema,
            totalRows: totalRows,
            metadata: metadata
        )
    }
}

/// Metadata about a Parquet file
public struct ParquetMetadata: Codable, Equatable {
    public let createdBy: String?
    public let version: String?
    public let rowGroups: Int
    public let compressionCodec: String?
    
    public init(createdBy: String? = nil, version: String? = nil, rowGroups: Int, compressionCodec: String? = nil) {
        self.createdBy = createdBy
        self.version = version
        self.rowGroups = rowGroups
        self.compressionCodec = compressionCodec
    }
}

// MARK: - Query Support

/// Result from a SQL query
public struct QueryResult {
    public let columns: [SchemaColumn]
    public let rows: [ParquetRow]
    
    public var rowCount: Int { rows.count }
    
    public init(columns: [SchemaColumn], rows: [ParquetRow]) {
        self.columns = columns
        self.rows = rows
    }
}