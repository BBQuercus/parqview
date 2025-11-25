import SwiftUI
import SharedCore

struct ImprovedMainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedColumns = Set<String>()
    @State private var filterText = ""
    @State private var activeFilter = ""
    @State private var isSearching = false

    var body: some View {
        ZStack {
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
                                    activeFilter: $activeFilter,
                                    isSearching: $isSearching,
                                    onBack: {
                                        appState.currentFile = nil
                                    }
                                )

                                Divider()

                                // Data table with pagination
                                SimpleVirtualTableView(file: file, filterText: activeFilter, isSearching: $isSearching, selectedColumns: selectedColumns)
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

            // Loading overlay when opening a file
            if appState.isLoading {
                ZStack {
                    Color(NSColor.windowBackgroundColor)
                        .opacity(0.9)

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle())

                        Text("Loading file...")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Reading schema and metadata")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                    )
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: appState.isLoading)
        .onChange(of: appState.currentFile?.id) { _ in
            // Reset state when file changes
            filterText = ""
            activeFilter = ""
            isSearching = false

            // Select all columns for the new file
            if let file = appState.currentFile {
                selectedColumns = Set(file.schema.columns.map { $0.name })
            }
        }
    }
}

struct HeaderToolbar: View {
    let file: ParquetFile
    @Binding var filterText: String
    @Binding var activeFilter: String
    @Binding var isSearching: Bool
    let onBack: () -> Void
    @FocusState private var isFilterFocused: Bool

    private var hasUnappliedChanges: Bool {
        filterText != activeFilter
    }

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
                    .foregroundStyle(isSearching ? Color.accentColor : Color.secondary)

                TextField("Filter data... (press Enter to search)", text: $filterText)
                    .textFieldStyle(.plain)
                    .focused($isFilterFocused)
                    .frame(width: 300)
                    .onSubmit {
                        performSearch()
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else if !filterText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }

                Button(action: performSearch) {
                    Text("Search")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSearching || !hasUnappliedChanges)
                .help(hasUnappliedChanges ? "Press Enter or click to search" : "Search is up to date")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(hasUnappliedChanges && !isSearching ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )

            Spacer()

            if !activeFilter.isEmpty {
                HStack(spacing: 4) {
                    Text("Filtered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }
            }

            Text("\(file.totalRows) rows")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func performSearch() {
        guard !isSearching else { return }
        activeFilter = filterText
    }

    private func clearSearch() {
        filterText = ""
        activeFilter = ""
        isFilterFocused = true
    }
}

struct SchemaSidebar: View {
    let schema: ParquetSchema
    @Binding var selectedColumns: Set<String>
    @State private var searchText = ""

    private var filteredColumns: [SchemaColumn] {
        if searchText.isEmpty {
            return schema.columns
        }
        return schema.columns.filter { column in
            column.name.localizedCaseInsensitiveContains(searchText) ||
            column.type.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Schema")
                    .font(.headline)
                Spacer()
                Text("\(selectedColumns.count)/\(schema.columns.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("Search columns...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // All/None buttons
            HStack(spacing: 8) {
                Button(action: selectAll) {
                    Text("All")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(allSelected)

                Button(action: selectNone) {
                    Text("None")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(noneSelected)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Column list
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if filteredColumns.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text("No matching columns")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(filteredColumns) { column in
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
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var allSelected: Bool {
        selectedColumns.count == schema.columns.count
    }

    private var noneSelected: Bool {
        selectedColumns.isEmpty
    }

    private func selectAll() {
        selectedColumns = Set(schema.columns.map { $0.name })
    }

    private func selectNone() {
        selectedColumns.removeAll()
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