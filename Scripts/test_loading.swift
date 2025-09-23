#!/usr/bin/env swift

import Foundation

// Define minimal async test
print("Testing file loading...")

// Simulate what AppState.loadFile does
let url = URL(fileURLWithPath: "test_data.parquet")

Task {
    print("File exists: \(FileManager.default.fileExists(atPath: url.path))")
    
    // Simulate the loading process
    print("Starting load...")
    
    // Get file attributes
    do {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeInBytes = fileAttributes[.size] as? Int64 ?? 0
        print("File size: \(sizeInBytes) bytes")
        
        // Try to execute Python script
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/python3")
        task.arguments = [
            "Sources/SharedCore/Scripts/parquet_reader.py",
            "metadata",
            url.path
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if task.terminationStatus == 0 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Metadata loaded successfully")
                print("  Rows: \(json["num_rows"] ?? "unknown")")
                print("  Columns: \(json["num_columns"] ?? "unknown")")
            } else {
                print("❌ Failed to parse JSON")
            }
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Python script failed: \(errorString)")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    exit(0)
}

// Keep running
RunLoop.main.run()