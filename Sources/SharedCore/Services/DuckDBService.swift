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

    /// Gets a filtered page of data - searches all columns for the filter text
    /// Returns (rows, totalMatchingRows)
    public func getFilteredPage(filterText: String, offset: Int, limit: Int) async throws -> ([ParquetRow], Int) {
        guard let path = currentFilePath else {
            throw DuckDBError.fileNotFound
        }

        let url = URL(fileURLWithPath: path)
        let totalRows = try ParquetBridge.shared.getRowCount(from: url)

        // For now, use in-memory filtering since DuckDB isn't fully integrated
        // Load batches and filter - stops early once we have enough results
        let batchSize = 5000
        var allMatchingRows: [ParquetRow] = []
        var currentBatchOffset = 0
        let neededRows = offset + limit

        while currentBatchOffset < totalRows {
            let rows = try ParquetBridge.shared.readSampleRows(
                from: url,
                limit: batchSize,
                offset: currentBatchOffset
            )

            if rows.isEmpty { break }

            // Filter rows using shared utility
            let matchingRows = rows.filter { row in
                row.values.contains { ValueFormatters.valueContains($0, searchText: filterText) }
            }

            allMatchingRows.append(contentsOf: matchingRows)
            currentBatchOffset += rows.count

            // Stop early if we have enough rows and scanned at least half the file
            if allMatchingRows.count >= neededRows + 500 && currentBatchOffset >= totalRows / 2 {
                break
            }
        }

        // Apply pagination
        let startIndex = min(offset, allMatchingRows.count)
        let endIndex = min(offset + limit, allMatchingRows.count)
        let pageRows = Array(allMatchingRows[startIndex..<endIndex])

        return (pageRows, allMatchingRows.count)
    }
    
    /// Executes a SQL statement without returning results
    private func execute(_ sql: String) async throws {
        // DuckDB integration pending - currently using ParquetBridge directly
        try await Task.sleep(nanoseconds: 10_000_000)
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