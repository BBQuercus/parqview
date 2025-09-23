#!/usr/bin/env swift

import Foundation
import SharedCore

// Test pagination and memory usage with large files

func testPagination() {
    print("🧪 Testing Pagination & Memory Usage")
    print("=====================================\n")
    
    let testFiles = [
        ("small_test.parquet", 100),
        ("test_1k.parquet", 1000),
        ("medium_test_data.parquet", 100000),
        ("large_test_data.parquet", 1000000)
    ]
    
    for (fileName, expectedRows) in testFiles {
        let url = URL(fileURLWithPath: fileName)
        
        guard FileManager.default.fileExists(atPath: fileName) else {
            print("⚠️ \(fileName) not found, skipping...")
            continue
        }
        
        print("📊 Testing: \(fileName) (\(expectedRows) rows)")
        print("-" * 40)
        
        do {
            // Test row count (should be instant)
            let countStart = Date()
            let rowCount = try ParquetBridge.shared.getRowCount(from: url)
            let countTime = Date().timeIntervalSince(countStart)
            print("  Row count: \(rowCount) in \(String(format: "%.3f", countTime))s")
            
            // Test small window loads (simulating pagination)
            let windowSize = 50
            var totalLoaded = 0
            var totalTime = 0.0
            
            // Load 5 random windows throughout the file
            let testOffsets = [0, rowCount/4, rowCount/2, 3*rowCount/4, max(0, rowCount-windowSize)]
            
            for offset in testOffsets where offset < rowCount {
                let start = Date()
                let rows = try ParquetBridge.shared.readSampleRows(from: url, limit: windowSize, offset: offset)
                let elapsed = Date().timeIntervalSince(start)
                totalTime += elapsed
                totalLoaded += rows.count
                
                print("  Window at \(offset): \(rows.count) rows in \(String(format: "%.3f", elapsed))s")
                
                // Clear cache to simulate real scrolling
                ParquetBridge.shared.clearCache(for: url)
            }
            
            print("  ✅ Loaded \(totalLoaded) rows total in \(String(format: "%.3f", totalTime))s")
            print("  Average: \(String(format: "%.3f", totalTime/Double(testOffsets.count)))s per window")
            
        } catch {
            print("  ❌ Error: \(error)")
        }
        
        print()
    }
    
    print("✨ Pagination test complete!")
}

// Run the test
testPagination()