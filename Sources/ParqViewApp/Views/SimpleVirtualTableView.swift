import SwiftUI
import SharedCore

/// Simple virtual table view that directly uses ParquetBridge for data loading
struct SimpleVirtualTableView: View {
    let file: ParquetFile
    
    @State private var visibleRows: [ParquetRow] = []
    @State private var isLoading = false
    @State private var currentOffset = 0
    
    private let pageSize = 50
    private let rowHeight: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(file.url.lastPathComponent)")
                    .font(.headline)
                Spacer()
                Text("\(file.totalRows) rows")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Column headers
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Text("#")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 60, height: 35)
                        .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                        .frame(height: 35)
                    
                    ForEach(file.schema.columns) { column in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(column.name)
                                .font(.system(size: 11, weight: .semibold))
                            Text(column.type.description)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .frame(minWidth: 150, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                            .frame(height: 35)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Data rows
            ScrollView([.horizontal, .vertical]) {
                if visibleRows.isEmpty && !isLoading {
                    Button("Load Data") {
                        loadData()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(visibleRows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 0) {
                                // Row number
                                Text("\(currentOffset + index + 1)")
                                    .font(.system(size: 11).monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, height: rowHeight)
                                
                                Divider()
                                    .frame(height: rowHeight)
                                
                                // Data cells
                                ForEach(Array(row.values.enumerated()), id: \.offset) { colIndex, value in
                                    if colIndex < file.schema.columns.count {
                                        cellView(for: value)
                                            .frame(minWidth: 150, height: rowHeight, alignment: .leading)
                                        
                                        Divider()
                                            .frame(height: rowHeight)
                                    }
                                }
                            }
                            .background(index % 2 == 0 ? Color.clear : Color(NSColor.separatorColor).opacity(0.05))
                        }
                    }
                }
            }
            
            Divider()
            
            // Pagination controls
            HStack {
                Button("Previous") {
                    loadPreviousPage()
                }
                .disabled(currentOffset == 0 || isLoading)
                
                Spacer()
                
                Text("Showing \(currentOffset + 1)-\(min(currentOffset + visibleRows.count, file.totalRows)) of \(file.totalRows)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Next") {
                    loadNextPage()
                }
                .disabled(currentOffset + pageSize >= file.totalRows || isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            loadData()
        }
    }
    
    @ViewBuilder
    private func cellView(for value: ParquetValue) -> some View {
        let displayText = getDisplayText(for: value)
        let textColor = getTextColor(for: value)
        
        Text(displayText)
            .font(.system(size: 11))
            .foregroundColor(textColor)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .help(displayText) // Tooltip
    }
    
    private func getDisplayText(for value: ParquetValue) -> String {
        switch value {
        case .null:
            return "NULL"
        case .bool(let b):
            return b ? "true" : "false"
        case .int(let i):
            return "\(i)"
        case .float(let f):
            return String(format: "%.2f", f)
        case .string(let s):
            return s
        case .binary(let data):
            return "<\(data.count) bytes>"
        case .date(let date):
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        case .timestamp(let date):
            return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)
        }
    }
    
    private func getTextColor(for value: ParquetValue) -> Color {
        switch value {
        case .null:
            return .secondary
        case .bool:
            return .purple
        case .int, .float:
            return .green
        case .string:
            return .primary
        case .binary:
            return .gray
        case .date, .timestamp:
            return .orange
        }
    }
    
    private func loadData() {
        Task {
            await loadPage(offset: currentOffset)
        }
    }
    
    private func loadNextPage() {
        Task {
            let newOffset = min(currentOffset + pageSize, file.totalRows - pageSize)
            await loadPage(offset: newOffset)
        }
    }
    
    private func loadPreviousPage() {
        Task {
            let newOffset = max(0, currentOffset - pageSize)
            await loadPage(offset: newOffset)
        }
    }
    
    @MainActor
    private func loadPage(offset: Int) async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            // Direct load using ParquetBridge
            let rows = try ParquetBridge.shared.readSampleRows(
                from: file.url,
                limit: pageSize,
                offset: offset
            )
            
            visibleRows = rows
            currentOffset = offset
        } catch {
            print("Error loading page at offset \(offset): \(error)")
            // Keep existing data on error
        }
        
        isLoading = false
    }
}