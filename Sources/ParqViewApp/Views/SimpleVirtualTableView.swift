import SwiftUI
import SharedCore

/// Simple virtual table view that directly uses ParquetBridge for data loading
struct SimpleVirtualTableView: View {
    let file: ParquetFile
    let filterText: String

    @State private var visibleRows: [ParquetRow] = []
    @State private var isLoading = false
    @State private var currentOffset = 0
    @State private var filteredTotalRows: Int = 0

    private let pageSize = 50
    private let rowHeight: CGFloat = 24
    private let columnWidth: CGFloat = 120
    private let rowNumberWidth: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 0) {
            // File header
            HStack {
                Text("\(file.url.lastPathComponent)")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if filteredTotalRows != file.totalRows && !filterText.isEmpty {
                    Text("\(filteredTotalRows) of \(file.totalRows) rows (filtered)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(file.totalRows) rows")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Synchronized scrolling for header and data
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        // Column headers - pinned at top
                        HStack(spacing: 0) {
                            Text("#")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: rowNumberWidth, height: rowHeight)
                                .background(Color(NSColor.controlBackgroundColor))

                            ForEach(file.schema.columns) { column in
                                HStack(spacing: 4) {
                                    Text(column.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                    Text("(\(column.type.shortDescription))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: columnWidth, height: rowHeight, alignment: .leading)
                                .padding(.horizontal, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }

                        Divider()

                        // Data rows
                        if visibleRows.isEmpty && !isLoading {
                            Text("No data")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else if isLoading && visibleRows.isEmpty {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ForEach(Array(visibleRows.enumerated()), id: \.offset) { index, row in
                                HStack(spacing: 0) {
                                    // Row number
                                    Text("\(currentOffset + index + 1)")
                                        .font(.system(size: 10).monospacedDigit())
                                        .foregroundColor(.secondary)
                                        .frame(width: rowNumberWidth, height: rowHeight)

                                    // Data cells
                                    ForEach(Array(row.values.enumerated()), id: \.offset) { colIndex, value in
                                        if colIndex < file.schema.columns.count {
                                            cellView(for: value)
                                                .frame(width: columnWidth, height: rowHeight, alignment: .leading)
                                                .padding(.horizontal, 6)
                                        }
                                    }
                                }
                                .background(index % 2 == 0 ? Color.clear : Color(NSColor.separatorColor).opacity(0.08))
                            }
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
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOffset == 0 || isLoading)

                Spacer()

                let totalRows = filterText.isEmpty ? file.totalRows : filteredTotalRows
                let endIndex = min(currentOffset + visibleRows.count, totalRows)
                Text("Showing \(visibleRows.isEmpty ? 0 : currentOffset + 1)-\(endIndex) of \(formatNumber(totalRows))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Next") {
                    loadNextPage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOffset + pageSize >= totalRows || isLoading)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            filteredTotalRows = file.totalRows
            loadData()
        }
        .onChange(of: filterText) { _ in
            currentOffset = 0
            loadData()
        }
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "'"
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
    
    @ViewBuilder
    private func cellView(for value: ParquetValue) -> some View {
        let displayText = getDisplayText(for: value)
        let textColor = getTextColor(for: value)

        Text(displayText)
            .font(.system(size: 10))
            .foregroundColor(textColor)
            .lineLimit(1)
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
        let totalRows = filterText.isEmpty ? file.totalRows : filteredTotalRows
        Task {
            let newOffset = min(currentOffset + pageSize, max(0, totalRows - pageSize))
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
            // Use DuckDB for filtered queries
            try await DuckDBService.shared.loadFile(at: file.url)

            if filterText.isEmpty {
                // No filter - simple pagination
                let rows = try await DuckDBService.shared.getPage(
                    offset: offset,
                    limit: pageSize
                )
                visibleRows = rows
                currentOffset = offset
                filteredTotalRows = file.totalRows
            } else {
                // With filter - use SQL WHERE clause
                let (rows, totalCount) = try await DuckDBService.shared.getFilteredPage(
                    filterText: filterText,
                    offset: offset,
                    limit: pageSize
                )
                visibleRows = rows
                currentOffset = offset
                filteredTotalRows = totalCount
            }
        } catch {
            print("Error loading page at offset \(offset): \(error)")
            // Fallback to ParquetBridge without filtering
            do {
                let rows = try ParquetBridge.shared.readSampleRows(
                    from: file.url,
                    limit: pageSize,
                    offset: offset
                )
                visibleRows = rows
                currentOffset = offset
                filteredTotalRows = file.totalRows
            } catch {
                print("Fallback also failed: \(error)")
            }
        }

        isLoading = false
    }
}