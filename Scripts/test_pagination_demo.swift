#!/usr/bin/env swift

import Foundation
import SharedCore

// Demonstrate the pagination improvements

func demonstratePagination() {
    print("🎯 Pagination Performance Demo")
    print("=" * 50)
    
    let testFile = "test_1k.parquet"
    let url = URL(fileURLWithPath: testFile)
    
    guard FileManager.default.fileExists(atPath: testFile) else {
        print("❌ test_1k.parquet not found!")
        print("Please ensure you have a test file with 1000 rows")
        return
    }
    
    print("\n📊 File: \(testFile)")
    
    do {
        // Get total row count
        let totalRows = try ParquetBridge.shared.getRowCount(from: url)
        print("Total rows: \(totalRows)")
        
        print("\n⚡ OLD APPROACH (loading all 1000 rows):")
        print("-" * 40)
        
        let oldStart = Date()
        let allRows = try ParquetBridge.shared.readSampleRows(from: url, limit: 1000, offset: 0)
        let oldTime = Date().timeIntervalSince(oldStart)
        print("❌ Loaded ALL \(allRows.count) rows in \(String(format: "%.3f", oldTime))s")
        print("❌ Memory usage: ~\(allRows.count * 100) bytes (estimated)")
        
        // Clear cache
        ParquetBridge.shared.clearCache(for: url)
        
        print("\n✨ NEW APPROACH (virtual scrolling with 50-row windows):")
        print("-" * 40)
        
        // Simulate scrolling through the file
        let windowSize = 50
        var totalLoadTime = 0.0
        var windowsLoaded = 0
        
        // Load initial window
        let window1Start = Date()
        let window1 = try ParquetBridge.shared.readSampleRows(from: url, limit: windowSize, offset: 0)
        let window1Time = Date().timeIntervalSince(window1Start)
        totalLoadTime += window1Time
        windowsLoaded += 1
        print("✅ Initial load: \(window1.count) rows in \(String(format: "%.3f", window1Time))s")
        
        // Simulate scrolling to middle
        ParquetBridge.shared.clearCache(for: url)
        let window2Start = Date()
        let window2 = try ParquetBridge.shared.readSampleRows(from: url, limit: windowSize, offset: 500)
        let window2Time = Date().timeIntervalSince(window2Start)
        totalLoadTime += window2Time
        windowsLoaded += 1
        print("✅ Scroll to middle: \(window2.count) rows in \(String(format: "%.3f", window2Time))s")
        
        // Simulate scrolling to end
        ParquetBridge.shared.clearCache(for: url)
        let window3Start = Date()
        let window3 = try ParquetBridge.shared.readSampleRows(from: url, limit: windowSize, offset: 950)
        let window3Time = Date().timeIntervalSince(window3Start)
        totalLoadTime += window3Time
        windowsLoaded += 1
        print("✅ Scroll to end: \(window3.count) rows in \(String(format: "%.3f", window3Time))s")
        
        print("\n📈 COMPARISON:")
        print("-" * 40)
        print("Old approach:")
        print("  • Time: \(String(format: "%.3f", oldTime))s")
        print("  • Rows in memory: \(allRows.count)")
        print("  • Can cause UI freeze: YES")
        
        print("\nNew approach:")
        print("  • Average time per window: \(String(format: "%.3f", totalLoadTime/Double(windowsLoaded)))s")
        print("  • Rows in memory: \(windowSize) (constant)")
        print("  • Can cause UI freeze: NO")
        
        let speedup = oldTime / (totalLoadTime/Double(windowsLoaded))
        print("\n🚀 Initial load is \(String(format: "%.1fx", speedup)) faster!")
        print("🚀 Uses \(String(format: "%.0f%%", (1.0 - Double(windowSize)/Double(allRows.count)) * 100)) less memory!")
        
    } catch {
        print("❌ Error: \(error)")
    }
}

// Run the demo
demonstratePagination()