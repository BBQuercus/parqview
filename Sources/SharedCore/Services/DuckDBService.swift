import Foundation

/// Service for executing SQL queries on Parquet files using DuckDB
/// DuckDB is an embedded SQL database that can query Parquet files directly
@MainActor
public class DuckDBService: ObservableObject {
    
    /// Shared instance for app-wide use
    public static let shared = DuckDBService()
    
    /// Current database connection
    private var database: OpaquePointer?
    
    /// Currently loaded file path
    private var currentFilePath: String?
    
    private init() {
        initializeDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Management
    
    /// Initialize DuckDB database
    private func initializeDatabase() {
        // TODO: Call DuckDB C API to create in-memory database
        // duckdb_open(nil, &database)
    }
    
    /// Close database connection
    nonisolated private func closeDatabase() {
        // TODO: Call DuckDB C API to close database
        // if database != nil {
        //     duckdb_close(&database)
        // }
    }
    
    // MARK: - File Operations
    
    /// Loads a Parquet file into DuckDB for querying
    /// Creates a view called 'parquet' that can be queried
    public func loadFile(at url: URL) async throws {
        let path = url.path
        
        // In DuckDB, we can query Parquet files directly without loading them
        // CREATE VIEW parquet AS SELECT * FROM read_parquet('path/to/file.parquet')
        let sql = """
            CREATE OR REPLACE VIEW parquet AS 
            SELECT * FROM read_parquet('\(path)')
        """
        
        try await execute(sql)
        currentFilePath = path
    }
    
    // MARK: - Data Operations
    
    /// Gets a page of data from the loaded file with optional sorting and filtering
    public func getPage(offset: Int, limit: Int, sortBy: String? = nil, ascending: Bool = true) async throws -> [ParquetRow] {
        // For now, use ParquetBridge directly until DuckDB is integrated
        guard let path = currentFilePath else {
            throw DuckDBError.fileNotFound
        }

        let url = URL(fileURLWithPath: path)

        // Read the data using ParquetBridge with offset support
        let rows = try ParquetBridge.shared.readSampleRows(from: url, limit: limit, offset: offset)

        // TODO: Implement proper pagination with offset when DuckDB is integrated
        // TODO: Implement sorting when DuckDB is integrated

        return rows
    }

    /// Gets a filtered page of data - searches all string columns for the filter text
    /// Returns (rows, totalMatchingRows)
    public func getFilteredPage(filterText: String, offset: Int, limit: Int) async throws -> ([ParquetRow], Int) {
        guard let path = currentFilePath else {
            throw DuckDBError.fileNotFound
        }

        let url = URL(fileURLWithPath: path)

        // Get schema to know which columns to search
        let schema = try ParquetBridge.shared.readSchema(from: url)

        // For now, use in-memory filtering since DuckDB isn't fully integrated
        // This loads more data and filters it - not ideal for huge files but works
        let searchText = filterText.lowercased()

        // Load a larger batch for filtering (up to 10000 rows at a time)
        let batchSize = 10000
        var allMatchingRows: [ParquetRow] = []
        var currentBatchOffset = 0
        var totalScanned = 0

        // Get total row count
        let totalRows = try ParquetBridge.shared.getRowCount(from: url)

        // Scan through the file in batches
        while currentBatchOffset < totalRows {
            let rows = try ParquetBridge.shared.readSampleRows(
                from: url,
                limit: batchSize,
                offset: currentBatchOffset
            )

            if rows.isEmpty {
                break
            }

            // Filter rows that contain the search text in any column
            let matchingRows = rows.filter { row in
                for value in row.values {
                    if valueContainsText(value, searchText: searchText) {
                        return true
                    }
                }
                return false
            }

            allMatchingRows.append(contentsOf: matchingRows)
            currentBatchOffset += rows.count
            totalScanned += rows.count

            // If we have enough matching rows, we can stop
            // (offset + limit + some buffer for accurate count)
            if allMatchingRows.count >= offset + limit + 1000 && currentBatchOffset >= totalRows / 2 {
                // Continue to get accurate count but we have enough data
            }
        }

        let totalMatching = allMatchingRows.count

        // Apply pagination to matching rows
        let startIndex = min(offset, allMatchingRows.count)
        let endIndex = min(offset + limit, allMatchingRows.count)
        let pageRows = Array(allMatchingRows[startIndex..<endIndex])

        return (pageRows, totalMatching)
    }

    /// Check if a value contains the search text
    private func valueContainsText(_ value: ParquetValue, searchText: String) -> Bool {
        switch value {
        case .null:
            return "null".contains(searchText)
        case .bool(let b):
            return String(b).lowercased().contains(searchText)
        case .int(let i):
            return String(i).contains(searchText)
        case .float(let f):
            return String(f).contains(searchText)
        case .string(let s):
            return s.lowercased().contains(searchText)
        case .binary:
            return false
        case .date(let d):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: d).lowercased().contains(searchText)
        case .timestamp(let t):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: t).lowercased().contains(searchText)
        }
    }
    
    /// Executes a SQL statement without returning results
    private func execute(_ sql: String) async throws {
        // TODO: Implement actual DuckDB execution
        // This would be used for CREATE VIEW, etc.
        
        // Simulate async work
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    
    /// Gets column statistics
    public func getColumnStats(columnName: String) async throws -> ColumnStatistics {
        let sql = """
            SELECT 
                COUNT(*) as count,
                COUNT(DISTINCT \(columnName)) as distinct_count,
                MIN(\(columnName)) as min_value,
                MAX(\(columnName)) as max_value,
                COUNT(*) - COUNT(\(columnName)) as null_count
            FROM parquet
        """
        
        // TODO: Execute and parse results
        return ColumnStatistics(
            count: 1000,
            distinctCount: 100,
            nullCount: 10,
            minValue: "A",
            maxValue: "Z"
        )
    }
    
    /// Exports data to CSV
    public func exportToCSV(outputPath: URL, limit: Int? = nil) async throws {
        // TODO: Implement CSV export when DuckDB is integrated
        // For now, this is a placeholder
        throw DuckDBError.queryFailed("Export not yet implemented")
    }
}

// MARK: - Supporting Types

/// Statistics for a column
public struct ColumnStatistics {
    public let count: Int
    public let distinctCount: Int
    public let nullCount: Int
    public let minValue: String?
    public let maxValue: String?
    
    public var nullPercentage: Double {
        guard count > 0 else { return 0 }
        return Double(nullCount) / Double(count) * 100
    }
}

// MARK: - Error Types

public enum DuckDBError: LocalizedError {
    case connectionFailed
    case queryFailed(String)
    case fileNotFound
    case invalidSQL(String)
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to DuckDB"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .fileNotFound:
            return "Parquet file not found"
        case .invalidSQL(let message):
            return "Invalid SQL: \(message)"
        }
    }
}

/*
 DuckDB C API Integration Notes:
 
 1. Include DuckDB header: #include <duckdb.h>
 
 2. Basic connection:
    duckdb_database db;
    duckdb_connection con;
    duckdb_open(nullptr, &db);  // In-memory database
    duckdb_connect(db, &con);
 
 3. Query execution:
    duckdb_result result;
    duckdb_query(con, "SELECT * FROM table", &result);
    
 4. Reading results:
    idx_t row_count = duckdb_row_count(&result);
    idx_t column_count = duckdb_column_count(&result);
    
    for (idx_t row = 0; row < row_count; row++) {
        for (idx_t col = 0; col < column_count; col++) {
            auto value = duckdb_value_varchar(&result, col, row);
            // Process value
            duckdb_free(value);
        }
    }
    
 5. Cleanup:
    duckdb_destroy_result(&result);
    duckdb_disconnect(&con);
    duckdb_close(&db);
 */