import SwiftUI
import SharedCore

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedColumns = Set<String>()
    @State private var filterText = ""
    @State private var filterColumn = ""
    @FocusState private var isFilterFocused: Bool
    
    var body: some View {
        NavigationView {
            if let file = appState.currentFile {
                HSplitView {
                // Schema panel
                SchemaPanel(
                    schema: file.schema,
                    selectedColumns: $selectedColumns
                )
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)
                
                // Data panel  
                VStack(spacing: 0) {
                    // Header bar with Back button and filter
                    HStack {
                        Button(action: {
                            appState.currentFile = nil
                        }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        
                        Divider()
                            .frame(height: 20)
                            .padding(.horizontal, 8)
                        
                        Label("Filter:", systemImage: "magnifyingglass")
                            .font(.caption)
                        
                        TextField("Enter filter text...", text: $filterText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                            .focused($isFilterFocused)
                            .onSubmit {
                                // Apply filter on Enter
                            }
                        
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
                        
                        Spacer()
                        
                        Text("\(file.totalRows) rows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    Divider()
                    
                    // Table
                    BasicTableView(
                        file: file,
                        selectedColumns: selectedColumns,
                        filterText: filterText
                    )
                }
                }
                .id(file.id)  // Force complete view recreation when file changes
                .navigationTitle(file.url.lastPathComponent)
                .onAppear {
                    // Always select all columns on appear
                    selectedColumns = Set(file.schema.columns.map { $0.name })
                }
            } else {
                SimpleWelcomeView()
            }
        }
        .onChange(of: appState.currentFile?.id) { _ in
            // Reset state when file changes
            filterText = ""
            filterColumn = ""
            
            // Select all columns for the new file
            if let file = appState.currentFile {
                selectedColumns = Set(file.schema.columns.map { $0.name })
            }
        }
    }
}

struct SimpleWelcomeView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Welcome to ParqView")
                .font(.largeTitle)
            
            Text("Open a Parquet file to get started")
                .foregroundStyle(.secondary)
            
            Button("Open File...") {
                appState.openDocument()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SchemaPanel: View {
    let schema: ParquetSchema
    @Binding var selectedColumns: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Schema")
                .font(.headline)
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(schema.columns) { column in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedColumns.contains(column.name) },
                                set: { isOn in
                                    if isOn {
                                        selectedColumns.insert(column.name)
                                    } else {
                                        selectedColumns.remove(column.name)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(column.name)
                                        .font(.system(size: 12))
                                    Text(column.type.description)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}