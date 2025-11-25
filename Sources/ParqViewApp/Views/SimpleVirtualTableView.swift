import SwiftUI
import SharedCore

/// Simple virtual table view that directly uses ParquetBridge for data loading
struct SimpleVirtualTableView: View {
    let file: ParquetFile
    let filterText: String
    @Binding var isSearching: Bool

    @AppStorage("rowsPerPage") private var rowsPerPage = 50
    @State private var visibleRows: [ParquetRow] = []
    @State private var isLoading = false
    @State private var currentOffset = 0
    @State private var filteredTotalRows: Int = 0
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
                ZStack {
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
                                VStack(spacing: 8) {
                                    Image(systemName: filterText.isEmpty ? "doc.text" : "magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text(filterText.isEmpty ? "No data" : "No matching results")
                                        .foregroundColor(.secondary)
                                    if !filterText.isEmpty {
                                        Text("Try a different search term")
                                            .font(.caption)
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 150)
                            } else if isLoading && visibleRows.isEmpty {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text(filterText.isEmpty ? "Loading data..." : "Searching...")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 150)
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
                    .opacity(isLoading && !visibleRows.isEmpty ? 0.5 : 1.0)

                    // Loading overlay when searching with existing data
                    if isLoading && !visibleRows.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Searching...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .cornerRadius(12)
                        .shadow(radius: 4)
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
                Text("Showing \(visibleRows.isEmpty ? 0 : currentOffset + 1)-\(endIndex) of \(ValueFormatters.formatNumber(totalRows))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Next") {
                    loadNextPage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOffset + rowsPerPage >= totalRows || isLoading)

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
        .task(id: filterText) {
            // Reset offset when filter changes
            currentOffset = 0
            filteredTotalRows = file.totalRows
            await loadPage(offset: 0)
        }
        .onChange(of: rowsPerPage) { _ in
            currentOffset = 0
            Task {
                await loadPage(offset: 0)
            }
        }
    }

    @ViewBuilder
    private func cellView(for value: ParquetValue) -> some View {
        let displayText = ValueFormatters.displayString(for: value)
        let colorType = ValueFormatters.color(for: value)

        Text(displayText)
            .font(.system(size: 10))
            .foregroundColor(swiftUIColor(for: colorType))
            .lineLimit(1)
            .help(displayText)
    }

    private func swiftUIColor(for colorType: ValueFormatters.ValueColor) -> Color {
        switch colorType {
        case .primary: return .primary
        case .secondary: return .secondary
        case .blue: return .blue
        case .green: return .green
        case .red: return .red
        case .orange: return .orange
        case .purple: return .purple
        }
    }
    
    private func loadNextPage() {
        let totalRows = filterText.isEmpty ? file.totalRows : filteredTotalRows
        Task {
            let newOffset = min(currentOffset + rowsPerPage, max(0, totalRows - rowsPerPage))
            await loadPage(offset: newOffset)
        }
    }

    private func loadPreviousPage() {
        Task {
            let newOffset = max(0, currentOffset - rowsPerPage)
            await loadPage(offset: newOffset)
        }
    }

    @MainActor
    private func loadPage(offset: Int) async {
        guard !isLoading else { return }

        isLoading = true
        isSearching = true

        defer {
            isLoading = false
            isSearching = false
        }

        do {
            // Use DuckDB for filtered queries
            try await DuckDBService.shared.loadFile(at: file.url)

            if filterText.isEmpty {
                // No filter - simple pagination
                let rows = try await DuckDBService.shared.getPage(
                    offset: offset,
                    limit: rowsPerPage
                )
                visibleRows = rows
                currentOffset = offset
                filteredTotalRows = file.totalRows
            } else {
                // With filter - use SQL WHERE clause
                let (rows, totalCount) = try await DuckDBService.shared.getFilteredPage(
                    filterText: filterText,
                    offset: offset,
                    limit: rowsPerPage
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
                    limit: rowsPerPage,
                    offset: offset
                )
                visibleRows = rows
                currentOffset = offset
                filteredTotalRows = file.totalRows
            } catch {
                print("Fallback also failed: \(error)")
            }
        }
    }
}