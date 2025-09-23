import SwiftUI
import SharedCore

/// Optimized table view with virtual scrolling and lazy loading
struct OptimizedTableView: View {
    let file: ParquetFile
    
    // Window of visible data
    @State private var visibleRows: [ParquetRow] = []
    @State private var visibleStartIndex = 0
    @State private var isLoading = false
    @State private var loadError: Error?
    
    // Configuration
    private let rowHeight: CGFloat = 30
    private let windowSize = 50  // Number of rows to keep in memory at once
    private let prefetchDistance = 10  // Start loading when this many rows from edge
    
    // Sorting
    @State private var sortColumn: String?
    @State private var sortAscending = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Table content with virtual scrolling
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            Section {
                                // Virtual spacer for rows above visible window
                                if visibleStartIndex > 0 {
                                    Color.clear
                                        .frame(height: CGFloat(visibleStartIndex) * rowHeight)
                                }
                                
                                // Visible rows or loading placeholder
                                if visibleRows.isEmpty && !isLoading {
                                    // No data loaded yet
                                    Text("No data loaded. Click to retry.")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 100)
                                        .onTapGesture {
                                            loadInitialData()
                                        }
                                } else if visibleRows.isEmpty && isLoading {
                                    // Loading state
                                    HStack {
                                        ProgressView()
                                        Text("Loading data...")
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 100)
                                } else {
                                    // Show actual rows
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
                                            checkAndLoadMore(localIndex: localIndex)
                                        }
                                    }
                                }
                                
                                // Virtual spacer for rows below visible window
                                let remainingRows = max(0, file.totalRows - visibleStartIndex - visibleRows.count)
                                if remainingRows > 0 {
                                    Color.clear
                                        .frame(height: CGFloat(remainingRows) * rowHeight)
                                }
                                
                            } header: {
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
                    .onAppear {
                        loadInitialData()
                    }
                    .onChange(of: sortColumn) { _ in
                        reloadData()
                    }
                    .onChange(of: sortAscending) { _ in
                        reloadData()
                    }
                }
            }
            
            // Status bar
            statusBar
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Virtual Table View - \(file.url.lastPathComponent)")
                .font(.headline)
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var statusBar: some View {
        HStack {
            if let error = loadError {
                Label("Error: \(error.localizedDescription)", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                let endIndex = min(visibleStartIndex + visibleRows.count, file.totalRows)
                Text("Showing \(visibleStartIndex + 1)-\(endIndex) of \(file.totalRows) rows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("Window size: \(windowSize) rows")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func loadInitialData() {
        print("🚀 loadInitialData called")
        // Reset state and load first window
        visibleRows = []
        visibleStartIndex = 0
        loadRows(startIndex: 0)
    }
    
    private func reloadData() {
        visibleStartIndex = 0
        loadRows(startIndex: 0)
    }
    
    private func checkAndLoadMore(localIndex: Int) {
        // Check if we need to load more data based on scroll position
        
        // Near the bottom of current window?
        if localIndex >= visibleRows.count - prefetchDistance {
            let nextStartIndex = visibleStartIndex + windowSize / 2
            if nextStartIndex < file.totalRows {
                loadRows(startIndex: nextStartIndex)
            }
        }
        
        // Near the top of current window?
        if localIndex <= prefetchDistance && visibleStartIndex > 0 {
            let prevStartIndex = max(0, visibleStartIndex - windowSize / 2)
            loadRows(startIndex: prevStartIndex)
        }
    }
    
    private func loadRows(startIndex: Int) {
        guard !isLoading else { return }
        guard startIndex >= 0 && startIndex < file.totalRows else { return }
        
        Task { @MainActor in
            isLoading = true
            loadError = nil
            
            print("📊 Loading rows from index \(startIndex)...")
            
            do {
                // Load the file into DuckDB if needed
                try await DuckDBService.shared.loadFile(at: file.url)
                
                // Load a window of rows
                let rows = try await DuckDBService.shared.getPage(
                    offset: startIndex,
                    limit: windowSize,
                    sortBy: sortColumn,
                    ascending: sortAscending
                )
                
                print("✅ Loaded \(rows.count) rows")
                
                // Update visible window
                visibleStartIndex = startIndex
                visibleRows = rows
                
            } catch {
                print("❌ Error loading rows at index \(startIndex): \(error)")
                loadError = error
                
                // Fallback: try using ParquetBridge directly
                do {
                    print("🔄 Trying fallback with ParquetBridge...")
                    let rows = try ParquetBridge.shared.readSampleRows(
                        from: file.url,
                        limit: windowSize,
                        offset: startIndex
                    )
                    print("✅ Fallback loaded \(rows.count) rows")
                    visibleStartIndex = startIndex
                    visibleRows = rows
                    loadError = nil
                } catch {
                    print("❌ Fallback also failed: \(error)")
                    if visibleRows.isEmpty {
                        visibleRows = []
                    }
                }
            }
            
            isLoading = false
        }
    }
    
    private func performSort(by column: String) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }
}

/// Alternative implementation using List for better performance
struct VirtualListTableView: View {
    let file: ParquetFile
    
    @State private var loadedChunks: [Int: [ParquetRow]] = [:]
    @State private var isLoadingChunk: Set<Int> = []
    
    private let chunkSize = 50
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(file.url.lastPathComponent) - \(file.totalRows) rows")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Virtual list
            List(0..<file.totalRows, id: \.self) { rowIndex in
                rowView(for: rowIndex)
                    .onAppear {
                        loadChunkIfNeeded(for: rowIndex)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func rowView(for index: Int) -> some View {
        let chunkIndex = index / chunkSize
        let rowInChunk = index % chunkSize
        
        if let chunk = loadedChunks[chunkIndex],
           rowInChunk < chunk.count {
            // Display the loaded row
            HStack {
                Text("\(index + 1)")
                    .frame(width: 50)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                ForEach(Array(chunk[rowInChunk].values.enumerated()), id: \.offset) { _, value in
                    TableCellView(value: value)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 30)
        } else {
            // Placeholder while loading
            HStack {
                Text("\(index + 1)")
                    .frame(width: 50)
                    .foregroundStyle(.secondary)
                
                if isLoadingChunk.contains(chunkIndex) {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 30)
        }
    }
    
    private func loadChunkIfNeeded(for rowIndex: Int) {
        let chunkIndex = rowIndex / chunkSize
        
        // Already loaded or loading?
        if loadedChunks[chunkIndex] != nil || isLoadingChunk.contains(chunkIndex) {
            return
        }
        
        // Load the chunk
        Task { @MainActor in
            isLoadingChunk.insert(chunkIndex)
            
            do {
                // Load the file into DuckDB if needed
                try await DuckDBService.shared.loadFile(at: file.url)
                
                // Load this chunk
                let startIndex = chunkIndex * chunkSize
                let rows = try await DuckDBService.shared.getPage(
                    offset: startIndex,
                    limit: chunkSize,
                    sortBy: nil,
                    ascending: true
                )
                
                loadedChunks[chunkIndex] = rows
                
                // Preload adjacent chunks
                preloadAdjacentChunks(around: chunkIndex)
                
                // Clean up distant chunks to save memory
                cleanupDistantChunks(from: chunkIndex)
                
            } catch {
                print("Failed to load chunk \(chunkIndex): \(error)")
            }
            
            isLoadingChunk.remove(chunkIndex)
        }
    }
    
    private func preloadAdjacentChunks(around chunkIndex: Int) {
        let maxChunks = (file.totalRows + chunkSize - 1) / chunkSize
        
        // Preload next and previous chunks
        for offset in [-1, 1] {
            let adjacentIndex = chunkIndex + offset
            if adjacentIndex >= 0 && adjacentIndex < maxChunks {
                loadChunkIfNeeded(for: adjacentIndex * chunkSize)
            }
        }
    }
    
    private func cleanupDistantChunks(from currentChunk: Int) {
        // Keep only chunks within 5 positions of current
        let keepDistance = 5
        
        loadedChunks = loadedChunks.filter { chunkIndex, _ in
            abs(chunkIndex - currentChunk) <= keepDistance
        }
    }
}