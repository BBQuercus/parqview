import SwiftUI
import SharedCore

/// Simple virtual table view that directly uses ParquetBridge for data loading
struct SimpleVirtualTableView: View {
    let file: ParquetFile
    let filterText: String
    @Binding var isSearching: Bool
    let selectedColumns: Set<String>

    @AppStorage("rowsPerPage") private var rowsPerPage = 25
    @State private var visibleRows: [ParquetRow] = []
    @State private var isLoading = false
    @State private var currentOffset = 0
    @State private var filteredTotalRows: Int = 0
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true
    @State private var selectedCell: (row: Int, col: String)? = nil
    @State private var jumpToRowText: String = ""
    @State private var showJumpPopover: Bool = false
    @State private var showExportAlert: Bool = false
    @State private var exportMessage: String = ""
    private let rowHeight: CGFloat = 24
    private let maxRowsForSorting = 100_000  // Limit sorting to avoid memory issues
    private let defaultColumnWidth: CGFloat = 120
    private let minColumnWidth: CGFloat = 60
    private let maxColumnWidth: CGFloat = 500
    private let rowNumberWidth: CGFloat = 50

    /// Columns to display based on selection
    private var visibleColumns: [SchemaColumn] {
        file.schema.columns.filter { selectedColumns.contains($0.name) }
    }

    /// Check if sorting is allowed (disabled for large files to prevent memory issues)
    private var canSort: Bool {
        file.totalRows <= maxRowsForSorting
    }

    /// Get width for a column (from state or default)
    private func columnWidth(for name: String) -> CGFloat {
        columnWidths[name] ?? defaultColumnWidth
    }

    /// Calculate optimal width for a column based on content
    private func calculateOptimalWidth(for column: SchemaColumn) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let headerFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let padding: CGFloat = 24 // horizontal padding (6 * 2) + some buffer

        // Measure header text
        let headerText = "\(column.name) (\(column.type.shortDescription))"
        var maxWidth = measureTextWidth(headerText, font: headerFont) + padding

        // Measure content in visible rows
        if let colIndex = file.schema.columns.firstIndex(where: { $0.name == column.name }) {
            for row in visibleRows {
                if colIndex < row.values.count {
                    let displayText = ValueFormatters.displayString(for: row.values[colIndex])
                    let textWidth = measureTextWidth(displayText, font: font) + padding
                    maxWidth = max(maxWidth, textWidth)
                }
            }
        }

        // Clamp to min/max
        return min(max(maxWidth, minColumnWidth), maxColumnWidth)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Synchronized scrolling for header and data
            GeometryReader { geometry in
                ZStack {
                    if visibleColumns.isEmpty {
                        // No columns selected
                        VStack(spacing: 12) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No columns selected")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Select columns from the sidebar to view data")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView([.horizontal, .vertical]) {
                            VStack(spacing: 0) {
                                // Column headers - pinned at top
                                HStack(spacing: 0) {
                                    Text("#")
                                        .font(.system(size: 10, weight: .semibold))
                                        .frame(width: rowNumberWidth, height: rowHeight)
                                        .background(Color(NSColor.controlBackgroundColor))

                                    ForEach(visibleColumns) { column in
                                        // Column header with sort button
                                        HStack(spacing: 2) {
                                            Text(column.name)
                                                .font(.system(size: 10, weight: .semibold))
                                                .lineLimit(1)
                                            Text("(\(column.type.shortDescription))")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)

                                            Spacer(minLength: 2)

                                            // Sort button
                                            Button(action: {
                                                if canSort {
                                                    toggleSort(for: column.name)
                                                }
                                            }) {
                                                Image(systemName: sortIcon(for: column.name))
                                                    .font(.system(size: 9))
                                                    .foregroundColor(
                                                        !canSort ? .secondary.opacity(0.2) :
                                                        sortColumn == column.name ? .accentColor : .secondary.opacity(0.5)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(!canSort)
                                            .help(!canSort
                                                ? "Sorting disabled for files > \(maxRowsForSorting / 1000)k rows"
                                                : sortColumn == column.name
                                                    ? (sortAscending ? "Sorted ascending - click for descending" : "Sorted descending - click to clear")
                                                    : "Sort by \(column.name)")
                                        }
                                        .frame(width: columnWidth(for: column.name), height: rowHeight, alignment: .leading)
                                        .padding(.horizontal, 6)
                                        .background(sortColumn == column.name
                                            ? Color.accentColor.opacity(0.1)
                                            : Color(NSColor.controlBackgroundColor))

                                        // Resize handle between columns
                                        ColumnResizeHandle(
                                            columnName: column.name,
                                            columnWidths: $columnWidths,
                                            defaultWidth: defaultColumnWidth,
                                            minWidth: minColumnWidth,
                                            maxWidth: maxColumnWidth,
                                            onAutoSize: {
                                                columnWidths[column.name] = calculateOptimalWidth(for: column)
                                            }
                                        )
                                        .frame(height: rowHeight)
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

                                            // Data cells - only for visible columns
                                            ForEach(visibleColumns) { column in
                                                if let colIndex = file.schema.columns.firstIndex(where: { $0.name == column.name }),
                                                   colIndex < row.values.count {
                                                    let globalRowIndex = currentOffset + index
                                                    let isSelected = selectedCell?.row == globalRowIndex && selectedCell?.col == column.name

                                                    cellView(for: row.values[colIndex])
                                                        .frame(width: columnWidth(for: column.name), height: rowHeight, alignment: .leading)
                                                        .padding(.horizontal, 6)
                                                        .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            selectedCell = (globalRowIndex, column.name)
                                                        }
                                                        .onTapGesture(count: 2) {
                                                            // Double-click to copy
                                                            copyValueToClipboard(row.values[colIndex])
                                                        }

                                                    // Divider line matching header
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 1, height: rowHeight)
                                                        .padding(.horizontal, 3.5)
                                                }
                                            }
                                        }
                                        .background(index % 2 == 0 ? Color.clear : Color(NSColor.separatorColor).opacity(0.08))
                                    }
                                }
                            }
                        }
                        .opacity(isLoading && !visibleRows.isEmpty ? 0.5 : 1.0)
                    }

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
            HStack(spacing: 8) {
                Button("Previous") {
                    loadPreviousPage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOffset == 0 || isLoading)
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                let totalRows = filterText.isEmpty ? file.totalRows : filteredTotalRows
                let endIndex = min(currentOffset + visibleRows.count, totalRows)
                Text("Showing \(visibleRows.isEmpty ? 0 : currentOffset + 1)-\(endIndex) of \(ValueFormatters.formatNumber(totalRows))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button("Next") {
                    loadNextPage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOffset + rowsPerPage >= totalRows || isLoading)
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Divider()
                    .frame(height: 16)

                // Jump to row
                Button(action: { showJumpPopover = true }) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Jump to row (⌘G)")
                .keyboardShortcut("g", modifiers: .command)
                .popover(isPresented: $showJumpPopover) {
                    VStack(spacing: 8) {
                        Text("Jump to Row")
                            .font(.headline)
                        HStack {
                            TextField("Row number", text: $jumpToRowText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .onSubmit {
                                    jumpToRow()
                                }
                            Button("Go") {
                                jumpToRow()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        Text("1 - \(totalRows)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Export to CSV
                Button(action: { exportToCSV() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export to CSV (⌘E)")
                .keyboardShortcut("e", modifiers: .command)

                // Copy selected cell
                Button(action: { copySelectedCell() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedCell == nil)
                .help("Copy selected cell (⌘C)")
                .keyboardShortcut("c", modifiers: .command)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .alert("Export Complete", isPresented: $showExportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportMessage)
            }
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

    /// Get the sort icon for a column
    private func sortIcon(for columnName: String) -> String {
        if sortColumn == columnName {
            return sortAscending ? "chevron.up" : "chevron.down"
        }
        return "chevron.up.chevron.down"
    }

    /// Toggle sorting for a column
    private func toggleSort(for columnName: String) {
        if sortColumn == columnName {
            if sortAscending {
                // Currently ascending, switch to descending
                sortAscending = false
            } else {
                // Currently descending, clear sort
                sortColumn = nil
                sortAscending = true
            }
        } else {
            // New column, sort ascending
            sortColumn = columnName
            sortAscending = true
        }
        // Reload data with new sort
        currentOffset = 0
        Task {
            await loadPage(offset: 0)
        }
    }

    /// Copy a value to clipboard
    private func copyValueToClipboard(_ value: ParquetValue) {
        let text = ValueFormatters.displayString(for: value)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Copy the currently selected cell
    private func copySelectedCell() {
        guard let cell = selectedCell else { return }
        let localIndex = cell.row - currentOffset
        guard localIndex >= 0 && localIndex < visibleRows.count else { return }

        if let colIndex = file.schema.columns.firstIndex(where: { $0.name == cell.col }),
           colIndex < visibleRows[localIndex].values.count {
            copyValueToClipboard(visibleRows[localIndex].values[colIndex])
        }
    }

    /// Jump to a specific row
    private func jumpToRow() {
        guard let rowNum = Int(jumpToRowText), rowNum >= 1 else {
            showJumpPopover = false
            return
        }

        let totalRows = filterText.isEmpty ? file.totalRows : filteredTotalRows
        let targetRow = min(max(1, rowNum), totalRows)
        let targetOffset = ((targetRow - 1) / rowsPerPage) * rowsPerPage

        showJumpPopover = false
        jumpToRowText = ""

        Task {
            await loadPage(offset: targetOffset)
        }
    }

    /// Export visible data to CSV
    private func exportToCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(file.name.replacingOccurrences(of: ".parquet", with: "")).csv"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                var csv = ""

                // Header row
                let headers = visibleColumns.map { $0.name }
                csv += headers.joined(separator: ",") + "\n"

                // Data rows
                for row in visibleRows {
                    var rowValues: [String] = []
                    for column in visibleColumns {
                        if let colIndex = file.schema.columns.firstIndex(where: { $0.name == column.name }),
                           colIndex < row.values.count {
                            let value = ValueFormatters.displayString(for: row.values[colIndex])
                            // Escape CSV values
                            if value.contains(",") || value.contains("\"") || value.contains("\n") {
                                rowValues.append("\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"")
                            } else {
                                rowValues.append(value)
                            }
                        }
                    }
                    csv += rowValues.joined(separator: ",") + "\n"
                }

                try csv.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "Exported \(visibleRows.count) rows to \(url.lastPathComponent)"
                showExportAlert = true
            } catch {
                exportMessage = "Export failed: \(error.localizedDescription)"
                showExportAlert = true
            }
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
                // No filter - simple pagination with optional sorting
                let rows = try await DuckDBService.shared.getPage(
                    offset: offset,
                    limit: rowsPerPage,
                    sortBy: sortColumn,
                    ascending: sortAscending
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

/// A draggable divider for resizing columns
struct ColumnResizeHandle: View {
    let columnName: String
    @Binding var columnWidths: [String: CGFloat]
    let defaultWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let onAutoSize: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var startWidth: CGFloat = 0

    private var currentWidth: CGFloat {
        columnWidths[columnName] ?? defaultWidth
    }

    var body: some View {
        ZStack {
            // Visible divider line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)

            // Wider hit area for easier grabbing
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8)
                .contentShape(Rectangle())
        }
        .overlay(
            // Highlight on hover/drag - offset during drag to show preview
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
                .opacity(isHovering || isDragging ? 1 : 0)
                .offset(x: isDragging ? dragOffset : 0)
        )
        .frame(width: 8)
        .onTapGesture(count: 2) {
            // Double-click to auto-size
            onAutoSize()
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        startWidth = currentWidth
                        isDragging = true
                    }
                    // Calculate clamped offset for preview
                    let newWidth = startWidth + value.translation.width
                    let clampedWidth = min(max(newWidth, minWidth), maxWidth)
                    dragOffset = clampedWidth - startWidth
                }
                .onEnded { value in
                    // Only update the actual width on drag end
                    let newWidth = startWidth + value.translation.width
                    let clampedWidth = min(max(newWidth, minWidth), maxWidth)
                    columnWidths[columnName] = clampedWidth
                    isDragging = false
                    dragOffset = 0
                    startWidth = 0
                }
        )
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// Helper to measure text width
func measureTextWidth(_ text: String, font: NSFont) -> CGFloat {
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = (text as NSString).size(withAttributes: attributes)
    return size.width
}