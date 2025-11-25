import SwiftUI

struct SettingsView: View {
    @AppStorage("rowsPerPage") private var rowsPerPage = 50

    var body: some View {
        Form {
            Picker("Rows per page:", selection: $rowsPerPage) {
                Text("25").tag(25)
                Text("50").tag(50)
                Text("100").tag(100)
                Text("250").tag(250)
            }
            .pickerStyle(.menu)

            Section {
                Text("File associations are managed by macOS. To set ParqView as the default app for .parquet files, select a parquet file in Finder, press Cmd+I, and change 'Open with' to ParqView.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 350, height: 150)
    }
}