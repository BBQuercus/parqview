#!/usr/bin/env swift

import Foundation
import SharedCore

// Test performance of the new C++ parquet reader

func testPerformance() {
    print("🚀 Testing Parquet reader performance...")
    
    // Test with different file sizes
    let testFiles = [
        "small_test.parquet",
        "test_1k.parquet",
        "medium_test_data.parquet",
        "large_test_data.parquet"
    ]
    
    for fileName in testFiles {
        let filePath = FileManager.default.currentDirectoryPath + "/" + fileName
        let url = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("⚠️ Test file \(fileName) not found, skipping...")
            continue
        }
        
        print("\n📊 Testing file: \(fileName)")
        
        // Test schema reading
        let schemaStart = Date()
        do {
            let schema = try ParquetBridge.shared.readSchema(from: url)
            let schemaTime = Date().timeIntervalSince(schemaStart)
            print("  ✅ Schema read: \(String(format: "%.3f", schemaTime))s - \(schema.columns.count) columns")
        } catch {
            print("  ❌ Schema read failed: \(error)")
        }
        
        // Test row count
        let countStart = Date()
        do {
            let rowCount = try ParquetBridge.shared.getRowCount(from: url)
            let countTime = Date().timeIntervalSince(countStart)
            print("  ✅ Row count: \(String(format: "%.3f", countTime))s - \(rowCount) rows")
        } catch {
            print("  ❌ Row count failed: \(error)")
        }
        
        // Test data reading (first 100 rows)
        let dataStart = Date()
        do {
            let rows = try ParquetBridge.shared.readSampleRows(from: url, limit: 100, offset: 0)
            let dataTime = Date().timeIntervalSince(dataStart)
            print("  ✅ First 100 rows: \(String(format: "%.3f", dataTime))s - \(rows.count) rows loaded")
        } catch {
            print("  ❌ Data read failed: \(error)")
        }
        
        // Test paginated reading (multiple pages)
        let paginatedStart = Date()
        var totalRows = 0
        do {
            for offset in stride(from: 0, to: 1000, by: 100) {
                let rows = try ParquetBridge.shared.readSampleRows(from: url, limit: 100, offset: offset)
                totalRows += rows.count
                if rows.isEmpty {
                    break
                }
            }
            let paginatedTime = Date().timeIntervalSince(paginatedStart)
            print("  ✅ Paginated read (10 pages): \(String(format: "%.3f", paginatedTime))s - \(totalRows) total rows")
        } catch {
            print("  ❌ Paginated read failed: \(error)")
        }
        
        // Clear cache for next test
        ParquetBridge.shared.clearCache(for: url)
    }
    
    print("\n✨ Performance testing complete!")
}

// Run the test
testPerformance()