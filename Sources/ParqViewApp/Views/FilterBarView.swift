import SwiftUI
import SharedCore

struct FilterBarView: View {
    let columns: [SchemaColumn]
    @Binding var filterText: String
    @Binding var filterColumn: String
    let onApplyFilter: () -> Void
    
    @State private var isFilterActive = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Filter icon and label
            Label("Filter", systemImage: isFilterActive ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                .font(.caption)
                .foregroundStyle(isFilterActive ? Color.accentColor : Color.secondary)
            
            // Column selector
            Picker("Column", selection: $filterColumn) {
                Text("All Columns").tag("")
                Divider()
                ForEach(columns) { column in
                    Text(column.name).tag(column.name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .controlSize(.small)
            
            // Filter text field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                
                TextField("Filter value...", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        applyFilter()
                    }
                
                if !filterText.isEmpty {
                    Button(action: clearFilter) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
            
            // Apply button
            Button(action: applyFilter) {
                Text("Apply")
                    .font(.caption)
            }
            .controlSize(.small)
            .disabled(filterText.isEmpty)
            
            // Clear button
            if isFilterActive {
                Button(action: clearFilter) {
                    Text("Clear")
                        .font(.caption)
                }
                .controlSize(.small)
            }
            
            Spacer()
            
            // Filter status
            if isFilterActive {
                Text("Filtered")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
    
    private func applyFilter() {
        isFilterActive = !filterText.isEmpty
        onApplyFilter()
    }
    
    private func clearFilter() {
        filterText = ""
        filterColumn = ""
        isFilterActive = false
        onApplyFilter()
    }
}