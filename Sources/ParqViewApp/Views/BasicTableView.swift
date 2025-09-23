import SwiftUI
import SharedCore

struct BasicTableView: View {
    let file: ParquetFile
    let selectedColumns: Set<String>
    let filterText: String
    
    @State private var allRows: [ParquetRow] = []
    @State private var isLoading = true
    @State private var currentOffset = 0
    @State private var pageSize = 100  // Reduced for faster initial load
    
    var visibleColumns: [SchemaColumn] {
        file.schema.columns.filter { selectedColumns.contains($0.name) }
    }
    
    var filteredRows: [ParquetRow] {
        guard !filterText.isEmpty else { return allRows }
        
        let searchText = filterText.lowercased()
        return allRows.filter { row in
            // Check each visible column for the filter text
            for column in visibleColumns {
                if let columnIndex = file.schema.columns.firstIndex(where: { $0.id == column.id }),
                   columnIndex < row.values.count {
                    if valueContainsText(row.values[columnIndex], searchText: searchText) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    private func valueContainsText(_ value: ParquetValue, searchText: String) -> Bool {
        switch value {
        case .null:
            return "null".contains(searchText)
        case .bool(let b):
            return String(b).lowercased().contains(searchText)
        case .int(let i):
            return String(i).lowercased().contains(searchText)
        case .float(let f):
            return String(f).lowercased().contains(searchText)
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
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading data...")
                Spacer()
            } else {
                tableContent
            }
        }
        .onAppear { loadData() }
        .onChange(of: file.id) { _ in loadData() }
    }
    
    @ViewBuilder
    var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                headerRow
                Divider()
                dataRows
            }
        }
    }
    
    @ViewBuilder
    var headerRow: some View {
        HStack(spacing: 0) {
            Text("#")
                .font(.caption.weight(.semibold))
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            
            ForEach(visibleColumns) { column in
                Text(column.name)
                    .font(.caption.weight(.semibold))
                    .frame(width: 150)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    @ViewBuilder
    var dataRows: some View {
        ForEach(Array(filteredRows.enumerated()), id: \.offset) { index, row in
            HStack(spacing: 0) {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60)
                    .padding(.vertical, 4)
                
                ForEach(visibleColumns) { column in
                    if let columnIndex = file.schema.columns.firstIndex(where: { $0.id == column.id }),
                       columnIndex < row.values.count {
                        CellView(value: row.values[columnIndex])
                            .frame(width: 150)
                    } else {
                        Text("")
                            .frame(width: 150)
                    }
                }
            }
            .background(index % 2 == 1 ? Color.gray.opacity(0.1) : Color.clear)
        }
    }
    
    private func loadData() {
        isLoading = true
        allRows = []
        
        // Store the current file URL to check if it's still the same after async operations
        let loadingFileURL = file.url
        
        Task {
            do {
                // First, ensure the file is loaded in DuckDB
                try await DuckDBService.shared.loadFile(at: file.url)
                
                // Check if we're still loading the same file
                guard loadingFileURL == file.url else {
                    print("⚠️ File changed while loading, skipping update")
                    return
                }
                
                // Then fetch the data using DuckDB
                let loadedRows = try await DuckDBService.shared.getPage(
                    offset: currentOffset,
                    limit: pageSize
                )
                
                // Check again before updating UI
                guard loadingFileURL == file.url else {
                    print("⚠️ File changed while fetching data, skipping update")
                    return
                }
                
                await MainActor.run {
                    // Final check before updating
                    guard loadingFileURL == self.file.url else {
                        print("⚠️ File changed before UI update, skipping")
                        return
                    }
                    self.allRows = loadedRows
                    self.isLoading = false
                }
            } catch {
                print("Error loading data: \(error)")
                await MainActor.run {
                    // Fallback to direct loading if DuckDB fails
                    do {
                        let fallbackRows = try ParquetBridge.shared.readSampleRows(from: file.url, limit: pageSize)
                        self.allRows = fallbackRows
                    } catch {
                        print("Fallback also failed: \(error)")
                        self.allRows = []
                    }
                    self.isLoading = false
                }
            }
        }
    }
}

struct CellView: View {
    let value: ParquetValue
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 4)
    }
    
    var displayText: String {
        switch value {
        case .null: return "NULL"
        case .bool(let b): return String(b)
        case .int(let i): return String(i)
        case .float(let f): return String(format: "%.2f", f)
        case .string(let s): return s
        case .binary: return "[Binary]"
        case .date(let d):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: d)
        case .timestamp(let t):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: t)
        }
    }
}