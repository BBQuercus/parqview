import Foundation
import SharedCore

// Test file opening directly
let fileURL = URL(fileURLWithPath: "test_data.parquet")

print("Testing file opening...")
print("File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")

// Test async loading
Task {
    do {
        print("Loading file...")
        let file = try await ParquetFile.load(from: fileURL)
        print("✅ File loaded successfully!")
        print("  Name: \(file.name)")
        print("  Size: \(file.sizeInBytes) bytes")
        print("  Rows: \(file.totalRows)")
        print("  Columns: \(file.schema.columns.count)")
        for column in file.schema.columns.prefix(5) {
            print("    - \(column.name): \(column.type)")
        }
    } catch {
        print("❌ Error loading file: \(error)")
    }
    exit(0)
}

// Keep the process alive
RunLoop.main.run()