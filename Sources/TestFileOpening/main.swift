import Foundation
import SharedCore
import SwiftUI
import AppKit

// Simple app to test file opening
@main
struct TestFileOpeningApp: App {
    @StateObject private var appState = TestAppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: TestAppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test File Opening")
                .font(.largeTitle)
            
            if appState.isLoading {
                ProgressView("Loading...")
            } else if let file = appState.currentFile {
                VStack(alignment: .leading) {
                    Text("File loaded successfully!")
                        .foregroundColor(.green)
                    Text("Name: \(file.name)")
                    Text("Rows: \(file.totalRows)")
                    Text("Columns: \(file.schema.columns.count)")
                }
            } else if let error = appState.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                Text("No file loaded")
            }
            
            Button("Open test_data.parquet") {
                appState.loadTestFile()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

@MainActor
class TestAppState: ObservableObject {
    @Published var currentFile: ParquetFile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadTestFile() {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/test_data.parquet")
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                print("Loading file from: \(url.path)")
                let file = try await ParquetFile.load(from: url)
                print("File loaded: \(file.name)")
                
                await MainActor.run {
                    self.currentFile = file
                    self.isLoading = false
                    print("State updated - currentFile is now set")
                }
            } catch {
                print("Error: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}