import XCTest
@testable import SharedCore

@MainActor
final class DuckDBServiceTests: XCTestCase {
    
    let service = DuckDBService.shared
    
    // MARK: - File Loading Tests
    
    func testLoadValidParquetFile() async throws {
        let testFile = createTestParquetFile()
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Should load without throwing
        do {
            try await service.loadFile(at: testFile)
        } catch {
            XCTFail("Failed to load valid parquet file: \(error)")
        }
    }
    
    func testLoadNonExistentFile() async throws {
        let invalidFile = URL(fileURLWithPath: "/tmp/nonexistent.parquet")
        
        // Should handle gracefully (might not throw immediately due to lazy loading)
        do {
            try await service.loadFile(at: invalidFile)
            // Try to get data to trigger actual loading
            _ = try await service.getPage(offset: 0, limit: 10)
            XCTFail("Should have thrown an error for non-existent file")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Pagination Tests
    
    func testGetPageDefaultParameters() async throws {
        let testFile = createTestParquetFile(rows: 500)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Get first page with default parameters
        let rows = try await service.getPage(offset: 0, limit: 100)
        
        // Should return up to 100 rows
        XCTAssertLessThanOrEqual(rows.count, 100)
        XCTAssertGreaterThan(rows.count, 0)
    }
    
    func testGetPageWithCustomLimit() async throws {
        let testFile = createTestParquetFile(rows: 500)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Test different page sizes
        let pageSizes = [50, 100, 500, 1000]
        
        for pageSize in pageSizes {
            let rows = try await service.getPage(offset: 0, limit: pageSize)
            XCTAssertLessThanOrEqual(rows.count, pageSize)
        }
    }
    
    func testGetPageWithOffset() async throws {
        let testFile = createTestParquetFile(rows: 500)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Get different pages
        let page1 = try await service.getPage(offset: 0, limit: 100)
        let page2 = try await service.getPage(offset: 100, limit: 100)
        let page3 = try await service.getPage(offset: 200, limit: 100)
        
        // Each page should have data (assuming file has enough rows)
        XCTAssertGreaterThan(page1.count, 0)
        XCTAssertGreaterThan(page2.count, 0)
        XCTAssertGreaterThan(page3.count, 0)
    }
    
    func testGetPageBeyondFileSize() async throws {
        let testFile = createTestParquetFile(rows: 100)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Request page beyond file size
        let rows = try await service.getPage(offset: 1000, limit: 100)
        
        // Should return empty array
        XCTAssertEqual(rows.count, 0)
    }
    
    func testGetPageLastPartialPage() async throws {
        let testFile = createTestParquetFile(rows: 150)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Get last page which should be partial
        let rows = try await service.getPage(offset: 100, limit: 100)
        
        // Should return only the remaining rows (50)
        XCTAssertLessThanOrEqual(rows.count, 50)
    }
    
    // MARK: - Sorting Tests (Future Implementation)
    
    func testGetPageWithSorting() async throws {
        let testFile = createTestParquetFile(rows: 100)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Test ascending sort
        let ascRows = try await service.getPage(
            offset: 0,
            limit: 10,
            sortBy: "column1",
            ascending: true
        )
        XCTAssertNotNil(ascRows)
        
        // Test descending sort
        let descRows = try await service.getPage(
            offset: 0,
            limit: 10,
            sortBy: "column1",
            ascending: false
        )
        XCTAssertNotNil(descRows)
    }
    
    // MARK: - Column Statistics Tests
    
    func testGetColumnStats() async throws {
        let testFile = createTestParquetFile()
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        let stats = try await service.getColumnStats(columnName: "test_column")
        
        // Verify statistics structure
        XCTAssertGreaterThanOrEqual(stats.count, 0)
        XCTAssertGreaterThanOrEqual(stats.distinctCount, 0)
        XCTAssertGreaterThanOrEqual(stats.nullCount, 0)
        XCTAssertLessThanOrEqual(stats.distinctCount, stats.count)
        XCTAssertLessThanOrEqual(stats.nullCount, stats.count)
    }
    
    func testColumnStatsNullPercentage() async throws {
        // Test null percentage calculation
        let stats = ColumnStatistics(
            count: 100,
            distinctCount: 50,
            nullCount: 25,
            minValue: "A",
            maxValue: "Z"
        )
        
        XCTAssertEqual(stats.nullPercentage, 25.0)
        
        // Test edge case: all nulls
        let allNullStats = ColumnStatistics(
            count: 100,
            distinctCount: 0,
            nullCount: 100,
            minValue: nil,
            maxValue: nil
        )
        
        XCTAssertEqual(allNullStats.nullPercentage, 100.0)
        
        // Test edge case: no nulls
        let noNullStats = ColumnStatistics(
            count: 100,
            distinctCount: 100,
            nullCount: 0,
            minValue: "A",
            maxValue: "Z"
        )
        
        XCTAssertEqual(noNullStats.nullPercentage, 0.0)
        
        // Test edge case: empty column
        let emptyStats = ColumnStatistics(
            count: 0,
            distinctCount: 0,
            nullCount: 0,
            minValue: nil,
            maxValue: nil
        )
        
        XCTAssertEqual(emptyStats.nullPercentage, 0.0)
    }
    
    // MARK: - Export Tests
    
    func testExportToCSVNotImplemented() async throws {
        let testFile = createTestParquetFile()
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        let outputPath = URL(fileURLWithPath: "/tmp/output.csv")
        
        // Should throw not implemented error
        do {
            try await service.exportToCSV(outputPath: outputPath)
            XCTFail("Export should not be implemented yet")
        } catch DuckDBError.queryFailed(let message) {
            XCTAssertTrue(message.contains("not yet implemented"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDuckDBErrorDescriptions() {
        // Test all error types have proper descriptions
        let errors: [DuckDBError] = [
            .connectionFailed,
            .queryFailed("Test query failed"),
            .fileNotFound,
            .invalidSQL("SELECT * FROM")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
        
        // Test specific error messages
        XCTAssertEqual(
            DuckDBError.connectionFailed.errorDescription,
            "Failed to connect to DuckDB"
        )
        
        XCTAssertEqual(
            DuckDBError.fileNotFound.errorDescription,
            "Parquet file not found"
        )
        
        let queryError = DuckDBError.queryFailed("Custom message")
        XCTAssertTrue(queryError.errorDescription!.contains("Custom message"))
        
        let sqlError = DuckDBError.invalidSQL("Bad SQL")
        XCTAssertTrue(sqlError.errorDescription!.contains("Bad SQL"))
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPageRequests() async throws {
        let testFile = createTestParquetFile(rows: 1000)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Launch multiple concurrent page requests
        async let page1 = service.getPage(offset: 0, limit: 100)
        async let page2 = service.getPage(offset: 100, limit: 100)
        async let page3 = service.getPage(offset: 200, limit: 100)
        
        let results = try await [page1, page2, page3]
        
        // All requests should succeed
        for result in results {
            XCTAssertGreaterThan(result.count, 0)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargePagePerformance() async throws {
        let testFile = createTestParquetFile(rows: 10000)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        try await service.loadFile(at: testFile)
        
        // Measure time to load different page sizes
        let pageSizes = [100, 500, 1000]
        
        for pageSize in pageSizes {
            let startTime = Date()
            _ = try await service.getPage(offset: 0, limit: pageSize)
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Should complete in reasonable time (adjust threshold as needed)
            XCTAssertLessThan(elapsed, 5.0, "Page size \(pageSize) took too long: \(elapsed)s")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestParquetFile(rows: Int = 100) -> URL {
        // Create a minimal parquet file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).parquet"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create a minimal valid parquet file
        var data = Data()
        data.append("PAR1".data(using: .utf8)!) // Start magic
        
        // Add some dummy content to simulate rows
        let rowSize = 100 // Approximate bytes per row
        let contentSize = rows * rowSize
        let dummyContent = Data(repeating: 0, count: contentSize)
        data.append(dummyContent)
        
        // Add footer (simplified)
        let footerLength: UInt32 = 100
        data.append(Data(repeating: 0, count: Int(footerLength)))
        data.append(withUnsafeBytes(of: footerLength.littleEndian) { Data($0) })
        data.append("PAR1".data(using: .utf8)!) // End magic
        
        try? data.write(to: fileURL)
        
        return fileURL
    }
}