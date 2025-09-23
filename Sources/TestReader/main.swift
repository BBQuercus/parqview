import Foundation
import SharedCore

// Test the ParquetBridge performance with different file sizes

func testFile(_ fileName: String) {
    let fileURL = URL(fileURLWithPath: fileName)
    
    guard FileManager.default.fileExists(atPath: fileName) else {
        print("⚠️ File not found: \(fileName)")
        return
    }
    
    print("\n📊 Testing: \(fileName)")
    print("==================================================")
    
    do {
        // Test schema reading
        let schemaStart = Date()
        let schema = try ParquetBridge.shared.readSchema(from: fileURL)
        let schemaTime = Date().timeIntervalSince(schemaStart)
        print("✅ Schema read in \(String(format: "%.3f", schemaTime))s - \(schema.columns.count) columns")
        
        // Test row count
        let countStart = Date()
        let rowCount = try ParquetBridge.shared.getRowCount(from: fileURL)
        let countTime = Date().timeIntervalSince(countStart)
        print("✅ Row count in \(String(format: "%.3f", countTime))s - \(rowCount) rows")
        
        // Test data reading (first batch)
        let dataStart = Date()
        let rows = try ParquetBridge.shared.readSampleRows(from: fileURL, limit: 100, offset: 0)
        let dataTime = Date().timeIntervalSince(dataStart)
        print("✅ First 100 rows in \(String(format: "%.3f", dataTime))s - \(rows.count) rows loaded")
        
        // Test random access (read from middle)
        if rowCount > 1000 {
            let midStart = Date()
            let midRows = try ParquetBridge.shared.readSampleRows(from: fileURL, limit: 100, offset: rowCount/2)
            let midTime = Date().timeIntervalSince(midStart)
            print("✅ Middle 100 rows in \(String(format: "%.3f", midTime))s - \(midRows.count) rows loaded")
        }
        
        // Test sequential reads (simulate pagination)
        let pageStart = Date()
        var totalPagedRows = 0
        for offset in stride(from: 0, to: min(1000, rowCount), by: 100) {
            let pageRows = try ParquetBridge.shared.readSampleRows(from: fileURL, limit: 100, offset: offset)
            totalPagedRows += pageRows.count
            if pageRows.isEmpty { break }
        }
        let pageTime = Date().timeIntervalSince(pageStart)
        print("✅ Paginated read (up to 10 pages) in \(String(format: "%.3f", pageTime))s - \(totalPagedRows) total rows")
        
        // Clear cache for fair comparison
        ParquetBridge.shared.clearCache(for: fileURL)
        
    } catch {
        print("❌ Error: \(error)")
    }
}

// Check if a specific file was provided as argument
if CommandLine.arguments.count > 1 {
    let fileName = CommandLine.arguments[1]
    testFile(fileName)
} else {
    // Test default files
    print("🚀 Testing Parquet Reader Performance")
    print("=====================================")
    
    let testFiles = [
        "small_test.parquet",
        "test_1k.parquet",
        "test_data.parquet",
        "medium_test_data.parquet",
        "large_test_data.parquet"
    ]
    
    for file in testFiles {
        testFile(file)
    }
    
    print("\n✨ Performance testing complete!")
}