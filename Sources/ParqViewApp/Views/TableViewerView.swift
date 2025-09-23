import SwiftUI
import SharedCore

struct TableViewerView: View {
    let file: ParquetFile
    
    // State for virtual scrolling with small window
    @State private var visibleRows: [ParquetRow] = []
    @State private var visibleStartIndex = 0
    @State private var isLoading = false
    @State private var sortColumn: String?
    @State private var sortAscending = true
    
    // Performance tuning
    private let windowSize = 50  // Only keep 50 rows in memory at once
    private let rowHeight: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                let endIndex = min(visibleStartIndex + visibleRows.count, file.totalRows)
                Text("Showing \(visibleRows.isEmpty ? 0 : visibleStartIndex + 1)-\(endIndex) of \(file.totalRows) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Table content with virtual scrolling
            if !visibleRows.isEmpty || isLoading {
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            Section {
                                // Virtual spacer for rows above
                                if visibleStartIndex > 0 {
                                    Color.clear
                                        .frame(height: CGFloat(visibleStartIndex) * rowHeight)
                                }
                                
                                // Visible rows only
                                ForEach(Array(visibleRows.enumerated()), id: \.offset) { localIndex, row in
                                    let globalIndex = visibleStartIndex + localIndex
                                    TableRowView(
                                        row: row,
                                        columns: file.schema.columns,
                                        rowIndex: globalIndex,
                                        isAlternate: globalIndex % 2 == 1
                                    )
                                    .frame(height: rowHeight)
                                    .id(globalIndex)
                                    .onAppear {
                                        // Load more data when approaching edges
                                        checkAndLoadMore(localIndex: localIndex)
                                    }
                                }
                                
                                // Virtual spacer for rows below
                                let remainingRows = max(0, file.totalRows - visibleStartIndex - visibleRows.count)
                                if remainingRows > 0 {
                                    Color.clear
                                        .frame(height: CGFloat(remainingRows) * rowHeight)
                                }
                            } header: {
                                // Table header
                                TableHeaderView(
                                    columns: file.schema.columns,
                                    sortColumn: $sortColumn,
                                    sortAscending: $sortAscending,
                                    onSort: { column in
                                        performSort(by: column)
                                    }
                                )
                            }
                        }
                        .frame(minHeight: CGFloat(file.totalRows) * rowHeight)
                    }
                }
            } else {
                // Empty or loading state
                VStack {
                    ProgressView("Loading data...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        loadWindowAt(startIndex: 0)
    }
    
    private func loadWindowAt(startIndex: Int) {
        guard !isLoading else { return }
        guard startIndex >= 0 && startIndex < file.totalRows else { return }
        
        Task { @MainActor in
            isLoading = true
            
            do {
                // Load the file into DuckDB service
                try await DuckDBService.shared.loadFile(at: file.url)
                
                // Load only a window of data
                let rows = try await DuckDBService.shared.getPage(
                    offset: startIndex,
                    limit: windowSize,
                    sortBy: sortColumn,
                    ascending: sortAscending
                )
                
                visibleStartIndex = startIndex
                visibleRows = rows
            } catch {
                print("Error loading data window at \(startIndex): \(error)")
                if visibleRows.isEmpty {
                    visibleRows = []
                }
            }
            
            isLoading = false
        }
    }
    
    private func reloadData() {
        visibleStartIndex = 0
        loadWindowAt(startIndex: 0)
    }
    
    private func checkAndLoadMore(localIndex: Int) {
        // Load more data when scrolling near edges of visible window
        let prefetchDistance = 10
        
        // Near bottom of window?
        if localIndex >= visibleRows.count - prefetchDistance {
            let nextStart = visibleStartIndex + windowSize / 2
            if nextStart < file.totalRows {
                loadWindowAt(startIndex: nextStart)
            }
        }
        
        // Near top of window?
        if localIndex <= prefetchDistance && visibleStartIndex > 0 {
            let prevStart = max(0, visibleStartIndex - windowSize / 2)
            loadWindowAt(startIndex: prevStart)
        }
    }
    
    private func performSort(by column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        
        // In real implementation, this would trigger a new query with ORDER BY
        reloadData()
    }
    
}

struct TableHeaderView: View {
    let columns: [SchemaColumn]
    @Binding var sortColumn: String?
    @Binding var sortAscending: Bool
    let onSort: (String) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Row number column
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Text("#")
                    .font(.caption.weight(.semibold))
            }
            .frame(width: 50, height: 30)
            
            Divider()
                .frame(height: 30)
            
            // Data columns
            ForEach(columns) { column in
                Button(action: { onSort(column.name) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(column.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if sortColumn == column.name {
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                        }
                        
                        Text(column.type.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minWidth: 100, maxWidth: 200, maxHeight: 30)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Rectangle()
                            .fill(Color.accentColor.opacity(sortColumn == column.name ? 0.1 : 0))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Divider()
                    .frame(height: 30)
            }
        }
    }
}

struct TableRowView: View {
    let row: ParquetRow
    let columns: [SchemaColumn]
    let rowIndex: Int
    let isAlternate: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Row number
            Text("\(rowIndex + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50)
                .padding(.vertical, 6)
            
            Divider()
                .frame(height: 20)
            
            // Data cells
            ForEach(Array(zip(columns, row.values)), id: \.0.id) { column, value in
                TableCellView(value: value)
                    .frame(minWidth: 100, maxWidth: 200)
                
                Divider()
                    .frame(height: 20)
            }
        }
        .background(isAlternate ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
    }
}

struct TableCellView: View {
    let value: ParquetValue
    
    var displayText: String {
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
    
    var textColor: Color {
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
    
    var body: some View {
        Text(displayText)
            .font(.caption.monospacedDigit())
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .help(displayText) // Tooltip for truncated text
    }
}