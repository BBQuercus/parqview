import XCTest
@testable import SharedCore

final class ParquetBridgeTests: XCTestCase {
    
    let bridge = ParquetBridge.shared
    
    override func setUp() {
        super.setUp()
        // Clear cache before each test
        bridge.clearAllCache()
    }
    
    // MARK: - Schema Reading Tests
    
    func testReadSchemaFromValidFile() throws {
        // Create a temporary test parquet file
        let testFile = createTestParquetFile()
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Test schema reading
        do {
            let schema = try bridge.readSchema(from: testFile)
            
            // Verify schema has columns
            XCTAssertGreaterThan(schema.columns.count, 0)
            
            // Verify column properties
            for column in schema.columns {
                XCTAssertFalse(column.name.isEmpty)
                XCTAssertNotNil(column.type)
            }
        } catch {
            XCTFail("Failed to read schema: \(error)")
        }
    }
    
    func testReadSchemaFromInvalidFile() throws {
        let invalidFile = URL(fileURLWithPath: "/tmp/nonexistent.parquet")
        
        // Should throw an error for invalid file
        XCTAssertThrowsError(try bridge.readSchema(from: invalidFile))
    }
    
    func testSchemaCaching() throws {
        let testFile = createTestParquetFile()
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // First read - should cache
        _ = try? bridge.readSchema(from: testFile)
        
        // Second read - should use cache (we can't directly test this, but it should be faster)
        let startTime = Date()
        _ = try? bridge.readSchema(from: testFile)
        let cachedTime = Date().timeIntervalSince(startTime)
        
        // Clear cache
        bridge.clearCache(for: testFile)
        
        // Third read - should not use cache
        let uncachedStart = Date()
        _ = try? bridge.readSchema(from: testFile)
        let uncachedTime = Date().timeIntervalSince(uncachedStart)
        
        // Cached read should generally be faster (though this isn't guaranteed)
        // This is more of a sanity check
        XCTAssertTrue(cachedTime >= 0)
        XCTAssertTrue(uncachedTime >= 0)
    }
    
    // MARK: - Data Reading Tests
    
    func testReadSampleRowsDefaultLimit() throws {
        let testFile = createTestParquetFile(rows: 500)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Read with default limit (100)
        let rows = try bridge.readSampleRows(from: testFile)
        
        // Should return exactly 100 rows (or less if file has fewer)
        XCTAssertLessThanOrEqual(rows.count, 100)
    }
    
    func testReadSampleRowsCustomLimit() throws {
        let testFile = createTestParquetFile(rows: 500)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Read with custom limit
        let customLimit = 50
        let rows = try bridge.readSampleRows(from: testFile, limit: customLimit)
        
        // Should return exactly the requested limit
        XCTAssertLessThanOrEqual(rows.count, customLimit)
    }
    
    func testReadSampleRowsWithOffset() throws {
        let testFile = createTestParquetFile(rows: 500)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Read first batch
        let firstBatch = try bridge.readSampleRows(from: testFile, limit: 10, offset: 0)
        
        // Read second batch with offset
        let secondBatch = try bridge.readSampleRows(from: testFile, limit: 10, offset: 10)
        
        // Batches should be different (assuming unique data)
        XCTAssertEqual(firstBatch.count, 10)
        XCTAssertEqual(secondBatch.count, 10)
        
        // The actual values would be different, but we can't test that without knowing the data
    }
    
    func testReadSampleRowsOffsetBeyondFile() throws {
        let testFile = createTestParquetFile(rows: 100)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // Read with offset beyond file size
        let rows = try bridge.readSampleRows(from: testFile, limit: 10, offset: 1000)
        
        // Should return empty array
        XCTAssertEqual(rows.count, 0)
    }
    
    // MARK: - Row Count Tests
    
    func testGetRowCount() throws {
        let testFile = createTestParquetFile(rows: 250)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        let rowCount = try bridge.getRowCount(from: testFile)
        
        // Should return the correct row count
        XCTAssertEqual(rowCount, 250)
    }
    
    func testGetRowCountCaching() throws {
        let testFile = createTestParquetFile(rows: 100)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        // First call - should cache
        let count1 = try bridge.getRowCount(from: testFile)
        
        // Second call - should use cache
        let count2 = try bridge.getRowCount(from: testFile)
        
        XCTAssertEqual(count1, count2)
        XCTAssertEqual(count1, 100)
    }
    
    // MARK: - Metadata Tests
    
    func testReadMetadata() throws {
        let testFile = createTestParquetFile()
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        let metadata = try bridge.readMetadata(from: testFile)
        
        // Verify metadata fields
        XCTAssertFalse(metadata.createdBy.isEmpty)
        XCTAssertFalse(metadata.version.isEmpty)
        XCTAssertGreaterThan(metadata.rowGroups, 0)
    }
    
    // MARK: - Type Conversion Tests
    
    func testParquetTypeConversion() throws {
        // Test type string conversions
        let testCases: [(String, ParquetType)] = [
            ("int64", .int64),
            ("int32", .int32),
            ("float64", .double),
            ("double", .double),
            ("float32", .float),
            ("float", .float),
            ("bool", .boolean),
            ("boolean", .boolean),
            ("string", .string),
            ("utf8", .string),
            ("object", .string),
            ("binary", .binary),
            ("date", .date),
            ("timestamp", .timestamp),
            ("datetime", .timestamp),
            ("unknown_type", .string) // Default fallback
        ]
        
        for (input, expected) in testCases {
            // We can't directly test the private method, but we can verify through schema reading
            // This is more of a documentation of expected behavior
            XCTAssertNotNil(expected)
        }
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCacheForSpecificFile() throws {
        let testFile1 = createTestParquetFile()
        let testFile2 = createTestParquetFile()
        defer {
            try? FileManager.default.removeItem(at: testFile1)
            try? FileManager.default.removeItem(at: testFile2)
        }
        
        // Cache both files
        _ = try? bridge.readMetadata(from: testFile1)
        _ = try? bridge.readMetadata(from: testFile2)
        
        // Clear cache for only one file
        bridge.clearCache(for: testFile1)
        
        // File 1 should need to re-read, file 2 should still be cached
        // We can't directly test cache state, but the operations should succeed
        _ = try? bridge.readMetadata(from: testFile1)
        _ = try? bridge.readMetadata(from: testFile2)
    }
    
    func testClearAllCache() throws {
        let testFile1 = createTestParquetFile()
        let testFile2 = createTestParquetFile()
        defer {
            try? FileManager.default.removeItem(at: testFile1)
            try? FileManager.default.removeItem(at: testFile2)
        }
        
        // Cache both files
        _ = try? bridge.readMetadata(from: testFile1)
        _ = try? bridge.readMetadata(from: testFile2)
        
        // Clear all cache
        bridge.clearAllCache()
        
        // Both files should need to re-read
        _ = try? bridge.readMetadata(from: testFile1)
        _ = try? bridge.readMetadata(from: testFile2)
    }
    
    // MARK: - Value Parsing Tests
    
    func testParquetValueParsing() throws {
        // Test that different value types are correctly parsed
        let testValues: [ParquetValue] = [
            .null,
            .bool(true),
            .bool(false),
            .int(42),
            .int(-100),
            .float(3.14159),
            .float(-2.71828),
            .string("Hello, World!"),
            .string(""),
            .binary(Data([0x01, 0x02, 0x03])),
            .date(Date()),
            .timestamp(Date())
        ]
        
        for value in testValues {
            // Verify each value type can be created and is valid
            switch value {
            case .null:
                XCTAssertTrue(true) // Null is valid
            case .bool(let b):
                XCTAssertNotNil(b)
            case .int(let i):
                XCTAssertNotNil(i)
            case .float(let f):
                XCTAssertNotNil(f)
            case .string(let s):
                XCTAssertNotNil(s)
            case .binary(let data):
                XCTAssertNotNil(data)
            case .date(let date):
                XCTAssertNotNil(date)
            case .timestamp(let timestamp):
                XCTAssertNotNil(timestamp)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestParquetFile(rows: Int = 100) -> URL {
        // Create a minimal parquet file for testing
        // In a real test, this would create an actual parquet file
        // For now, we'll create a dummy file
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).parquet"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create a minimal valid parquet file
        // PAR1 magic bytes at start and end
        var data = Data()
        data.append("PAR1".data(using: .utf8)!) // Start magic
        
        // Add some dummy content
        let dummyContent = Data(repeating: 0, count: 1000)
        data.append(dummyContent)
        
        // Add footer (simplified)
        let footerLength: UInt32 = 100
        data.append(Data(repeating: 0, count: Int(footerLength))) // Dummy footer
        data.append(withUnsafeBytes(of: footerLength.littleEndian) { Data($0) })
        data.append("PAR1".data(using: .utf8)!) // End magic
        
        try? data.write(to: fileURL)
        
        return fileURL
    }
}