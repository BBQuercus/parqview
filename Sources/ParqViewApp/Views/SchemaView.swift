import SwiftUI
import SharedCore

struct SchemaView: View {
    let schema: ParquetSchema?
    @Binding var selectedColumn: SchemaColumn?
    
    // @State for search/filter functionality
    @State private var searchText = ""
    
    var filteredColumns: [SchemaColumn] {
        guard let columns = schema?.columns else { return [] }
        
        if searchText.isEmpty {
            return columns
        }
        
        return columns.filter { column in
            column.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Schema", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                if let count = schema?.columns.count {
                    Text("\(count) columns")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter columns", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Column list
            if schema != nil {
                List(filteredColumns, selection: $selectedColumn) { column in
                    ColumnRowView(column: column)
                }
                .listStyle(.sidebar)
            } else {
                // Empty state
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No schema loaded")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct ColumnRowView: View {
    let column: SchemaColumn
    
    var typeIcon: String {
        // Map Parquet types to SF Symbols
        switch column.type {
        case .string:
            return "textformat"
        case .int32, .int64:
            return "number"
        case .float, .double:
            return "number.circle"
        case .boolean:
            return "switch.2"
        case .date:
            return "calendar"
        case .timestamp:
            return "clock"
        case .binary:
            return "doc.zipper"
        default:
            return "questionmark.circle"
        }
    }
    
    var typeColor: Color {
        switch column.type {
        case .string:
            return .blue
        case .int32, .int64, .float, .double:
            return .green
        case .boolean:
            return .purple
        case .date, .timestamp:
            return .orange
        case .binary:
            return .gray
        default:
            return .secondary
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: typeIcon)
                .foregroundStyle(typeColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(column.name)
                    .lineLimit(1)
                
                Text(column.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if column.isNullable {
                Text("nullable")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.systemGray).opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle()) // Makes entire row clickable
    }
}