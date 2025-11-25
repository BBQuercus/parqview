import SwiftUI
import SharedCore

struct ImprovedMainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedColumns = Set<String>()
    @State private var filterText = ""
    @State private var sortColumn: String? = nil
    @State private var sortAscending = true
    
    var body: some View {
        let _ = print("🎨 ImprovedMainView rendering. currentFile: \(appState.currentFile != nil ? "EXISTS" : "nil"), isLoading: \(appState.isLoading), error: \(appState.errorMessage ?? "none")")
        Group {
            if let file = appState.currentFile {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Schema sidebar
                        SchemaSidebar(
                            schema: file.schema,
                            selectedColumns: $selectedColumns
                        )
                        .frame(width: 250)
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        // Main content area
                        VStack(spacing: 0) {
                            // Header toolbar
                            HeaderToolbar(
                                file: file,
                                filterText: $filterText,
                                onBack: {
                                    appState.currentFile = nil
                                }
                            )
                            
                            Divider()
                            
                            // Data table - Use optimized view for large files
                            if file.totalRows > 500 {
                                // Use simple paginated view for large files
                                SimpleVirtualTableView(file: file, filterText: filterText)
                            } else {
                                // Use simple view for small files
                                ImprovedTableView(
                                    file: file,
                                    selectedColumns: selectedColumns,
                                    filterText: filterText,
                                    sortColumn: sortColumn,
                                    sortAscending: sortAscending,
                                    onSort: handleSort
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .id(file.id)  // Force complete view recreation when file changes
                .onAppear {
                    // Always select all columns on appear
                    selectedColumns = Set(file.schema.columns.map { $0.name })
                }
            } else {
                WelcomeScreen()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: appState.currentFile?.id) { _ in
            // Reset state when file changes
            filterText = ""
            sortColumn = nil
            sortAscending = true
            
            // Select all columns for the new file
            if let file = appState.currentFile {
                selectedColumns = Set(file.schema.columns.map { $0.name })
            }
        }
    }
    
    private func handleSort(column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }
}

struct HeaderToolbar: View {
    let file: ParquetFile
    @Binding var filterText: String
    let onBack: () -> Void
    @FocusState private var isFilterFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            
            Divider()
                .frame(height: 20)
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Filter data...", text: $filterText)
                    .textFieldStyle(.plain)
                    .focused($isFilterFocused)
                    .frame(width: 300)
                
                if !filterText.isEmpty {
                    Button(action: {
                        filterText = ""
                        isFilterFocused = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            
            Spacer()
            
            Text("\(file.totalRows) rows")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SchemaSidebar: View {
    let schema: ParquetSchema
    @Binding var selectedColumns: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Schema")
                    .font(.headline)
                Spacer()
                Button(action: toggleAll) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Column list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(schema.columns) { column in
                        ColumnCheckbox(
                            column: column,
                            isSelected: selectedColumns.contains(column.name),
                            onToggle: {
                                if selectedColumns.contains(column.name) {
                                    selectedColumns.remove(column.name)
                                } else {
                                    selectedColumns.insert(column.name)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var allSelected: Bool {
        selectedColumns.count == schema.columns.count
    }
    
    private func toggleAll() {
        if allSelected {
            selectedColumns.removeAll()
        } else {
            selectedColumns = Set(schema.columns.map { $0.name })
        }
    }
}

struct ColumnCheckbox: View {
    let column: SchemaColumn
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.system(size: 13))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(column.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                    
                    Text(column.type.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct ImprovedTableView: View {
    let file: ParquetFile
    let selectedColumns: Set<String>
    let filterText: String
    let sortColumn: String?
    let sortAscending: Bool
    let onSort: (String) -> Void
    
    @State private var allRows: [ParquetRow] = []
    @State private var isLoading = true
    
    var visibleColumns: [SchemaColumn] {
        file.schema.columns.filter { selectedColumns.contains($0.name) }
    }
    
    var filteredRows: [ParquetRow] {
        guard !filterText.isEmpty else { return sortedRows }
        
        let searchText = filterText.lowercased()
        return sortedRows.filter { row in
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
    
    var sortedRows: [ParquetRow] {
        guard let sortCol = sortColumn,
              let columnIndex = file.schema.columns.firstIndex(where: { $0.name == sortCol }) else {
            return allRows
        }
        
        return allRows.sorted { row1, row2 in
            guard columnIndex < row1.values.count && columnIndex < row2.values.count else {
                return true
            }
            
            let comparison = compareValues(row1.values[columnIndex], row2.values[columnIndex])
            return sortAscending ? comparison : !comparison
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Row count toolbar
            HStack {
                Text("Showing \(filteredRows.isEmpty ? 0 : 1)-\(filteredRows.count) of \(file.totalRows) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            Group {
                if isLoading {
                    ProgressView("Loading data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visibleColumns.isEmpty {
                    Text("No columns selected")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        // Header
                        HStack(spacing: 0) {
                            // Row number header
                            Text("#")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 50)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            // Column headers
                            ForEach(visibleColumns) { column in
                                ColumnHeader(
                                    column: column,
                                    isSorted: sortColumn == column.name,
                                    isAscending: sortAscending,
                                    onTap: { onSort(column.name) }
                                )
                                
                                Divider()
                            }
                        }
                        
                        Divider()
                        
                        // Data rows
                        ForEach(Array(filteredRows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 0) {
                                // Row number
                                Text("\(index + 1)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50)
                                    .padding(.vertical, 6)
                                
                                Divider()
                                
                                // Data cells
                                ForEach(visibleColumns) { column in
                                    if let columnIndex = file.schema.columns.firstIndex(where: { $0.id == column.id }),
                                       columnIndex < row.values.count {
                                        DataCell(value: row.values[columnIndex])
                                    } else {
                                        Text("")
                                            .frame(minWidth: 100, maxWidth: 300, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                    }
                                    
                                    Divider()
                                }
                            }
                            .background(index % 2 == 1 ? Color(NSColor.separatorColor).opacity(0.05) : Color.clear)
                        }
                    }
                }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onAppear { loadData() }
    }
    
    private func loadData() {
        Task {
            isLoading = true
            do {
                try await DuckDBService.shared.loadFile(at: file.url)
                // Only load up to 500 rows for the simple view
                let limit = min(500, file.totalRows)
                let rows = try await DuckDBService.shared.getPage(offset: 0, limit: limit)
                
                await MainActor.run {
                    self.allRows = rows
                    self.isLoading = false
                }
            } catch {
                print("Error loading data: \(error)")
                // Try fallback
                do {
                    let limit = min(500, file.totalRows)
                    let rows = try ParquetBridge.shared.readSampleRows(from: file.url, limit: limit)
                    await MainActor.run {
                        self.allRows = rows
                        self.isLoading = false
                    }
                } catch {
                    print("Fallback also failed: \(error)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            }
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
    
    private func compareValues(_ v1: ParquetValue, _ v2: ParquetValue) -> Bool {
        switch (v1, v2) {
        case (.null, .null):
            return true
        case (.null, _):
            return true
        case (_, .null):
            return false
        case (.bool(let b1), .bool(let b2)):
            return !b1 && b2
        case (.int(let i1), .int(let i2)):
            return i1 < i2
        case (.float(let f1), .float(let f2)):
            return f1 < f2
        case (.string(let s1), .string(let s2)):
            return s1 < s2
        case (.date(let d1), .date(let d2)):
            return d1 < d2
        case (.timestamp(let t1), .timestamp(let t2)):
            return t1 < t2
        default:
            return String(describing: v1) < String(describing: v2)
        }
    }
}

struct ColumnHeader: View {
    let column: SchemaColumn
    let isSorted: Bool
    let isAscending: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(column.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(column.type.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSorted {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minWidth: 100, maxWidth: 300, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSorted ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct DataCell: View {
    let value: ParquetValue
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 12))
            .lineLimit(1)
            .frame(minWidth: 100, maxWidth: 300, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }
    
    var displayText: String {
        switch value {
        case .null:
            return "NULL"
        case .bool(let b):
            return String(b)
        case .int(let i):
            return String(i)
        case .float(let f):
            return String(format: "%.2f", f)
        case .string(let s):
            return s
        case .binary:
            return "[Binary]"
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

struct WelcomeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDragTargeted = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
            Image(systemName: isDragTargeted ? "arrow.down.doc.fill" : "doc.text.magnifyingglass")
                .font(.system(size: 72))
                .foregroundStyle(isDragTargeted ? Color.accentColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isDragTargeted)
            
            Text("Welcome to ParqView")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text(isDragTargeted ? "Drop your Parquet file here" : "Open a Parquet file to get started")
                .font(.title3)
                .foregroundStyle(isDragTargeted ? Color.accentColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isDragTargeted)
            
            Button(action: {
                appState.openDocument()
            }) {
                Label("Open File...", systemImage: "folder.open")
                    .frame(width: 200)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            
            Text("or drag and drop a .parquet file")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Show error if there is one
            if let error = appState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        // Loading overlay
        if appState.isLoading {
            ProgressView("Loading file...")
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 5)
        }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragTargeted ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
                )
                .padding(20)
        )
        .background(Color(NSColor.windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
            DispatchQueue.main.async {
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    let validExtensions = ["parquet", "parq"]
                    if validExtensions.contains(url.pathExtension.lowercased()) {
                        appState.loadFile(at: url)
                    } else {
                        appState.errorMessage = "Please drop a valid Parquet file (.parquet or .parq)"
                    }
                }
            }
        }
        
        return true
    }
}