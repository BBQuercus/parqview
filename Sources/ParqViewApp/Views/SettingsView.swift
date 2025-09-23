import SwiftUI

struct SettingsView: View {
    // @AppStorage persists these values in UserDefaults
    @AppStorage("defaultRowsPerPage") private var defaultRowsPerPage = 100
    @AppStorage("enableSQLHighlighting") private var enableSQLHighlighting = true
    @AppStorage("showNullAsGray") private var showNullAsGray = true
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                defaultRowsPerPage: $defaultRowsPerPage
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppearanceSettingsView(
                enableSQLHighlighting: $enableSQLHighlighting,
                showNullAsGray: $showNullAsGray
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            PerformanceSettingsView()
            .tabItem {
                Label("Performance", systemImage: "speedometer")
            }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @Binding var defaultRowsPerPage: Int
    
    var body: some View {
        Form {
            Picker("Default rows per page:", selection: $defaultRowsPerPage) {
                Text("50").tag(50)
                Text("100").tag(100)
                Text("500").tag(500)
                Text("1000").tag(1000)
            }
            .pickerStyle(.menu)
            
            Section {
                Text("File associations are managed by macOS. To set ParqView as the default app for .parquet files, select a parquet file in Finder, press Cmd+I, and change 'Open with' to ParqView.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @Binding var enableSQLHighlighting: Bool
    @Binding var showNullAsGray: Bool
    
    var body: some View {
        Form {
            Toggle("Enable SQL syntax highlighting", isOn: $enableSQLHighlighting)
            Toggle("Show NULL values in gray", isOn: $showNullAsGray)
            
            Section {
                Text("Appearance settings affect how data is displayed in the table viewer and query results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct PerformanceSettingsView: View {
    @AppStorage("enableLazyLoading") private var enableLazyLoading = true
    @AppStorage("cacheSize") private var cacheSize = 100 // MB
    
    var body: some View {
        Form {
            Toggle("Enable lazy loading", isOn: $enableLazyLoading)
                .help("Load table data on-demand as you scroll")
            
            Stepper("Cache size: \(cacheSize) MB", value: $cacheSize, in: 50...1000, step: 50)
                .help("Amount of memory to use for caching query results")
            
            Section {
                Text("Performance settings control memory usage and loading behavior. Adjust these if you're working with very large files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}