import SwiftUI
import SharedCore
import UniformTypeIdentifiers
import AppKit

// Custom AppDelegate to handle file opening from Finder
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    
    var appState: AppState?
    var pendingURLs: [URL] = []
    var retryTimer: Timer?
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Ensure the app becomes active
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.setActivationPolicy(.regular)
        
        // Start the retry timer early
        startRetryTimer()
        
        // Always ensure window creation
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            // Try to trigger window creation by showing the app
            NSApplication.shared.unhide(nil)
            NSApplication.shared.arrangeInFront(nil)
            
            // Force window to front
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log window status
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
        let timestamp = Date().description
        let logMessage = "[\(timestamp)] applicationDidFinishLaunching - Windows count: \(NSApplication.shared.windows.count)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
        
        // Ensure window is shown when app launches
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Force window to appear with more aggressive approach
        DispatchQueue.main.async {
            // If no windows exist, force window creation
            if NSApplication.shared.windows.isEmpty {
                // This should force SwiftUI to create the window
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.setActivationPolicy(.regular)
                
                // Wait a bit and try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.center()
                        window.makeMain()
                        window.orderFrontRegardless()
                    }
                }
            } else {
                // Show existing window
                if let window = NSApplication.shared.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.center()
                    window.makeMain()
                    window.orderFrontRegardless()
                    
                    // Make sure window is visible
                    if !window.isVisible {
                        window.setIsVisible(true)
                    }
                }
            }
            
            // Make sure app is in foreground
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.unhide(nil)
            
            // Bring to front
            if NSApplication.shared.isHidden {
                NSApplication.shared.unhide(nil)
            }
        }
        
        // Start a timer to retry processing pending URLs until appState is ready
        startRetryTimer()
    }
    
    func startRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.appState != nil && !self.pendingURLs.isEmpty {
                self.processPendingURLs()
                self.retryTimer?.invalidate()
                self.retryTimer = nil
            }
        }
        
        // Stop trying after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.retryTimer?.invalidate()
            self?.retryTimer = nil
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        print("📂 AppDelegate: application:open: called with \(urls.count) URLs")
        
        // Log to file
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
        let timestamp = Date().description
        var logMessage = "[\(timestamp)] AppDelegate: application:open: called with URLs: \(urls.map { $0.path }.joined(separator: ", "))\n"
        
        // Force window creation if no windows exist
        if NSApplication.shared.windows.isEmpty {
            logMessage += "[\(timestamp)] No windows exist, forcing window creation\n"
            // Force the app to create its main window
            NSApplication.shared.activate(ignoringOtherApps: true)
            // This should trigger SwiftUI to create the window
            NSApplication.shared.setActivationPolicy(.regular)
        }
        
        // Open the first valid parquet file
        for url in urls {
            if ["parquet", "parq"].contains(url.pathExtension.lowercased()) {
                if let appState = appState {
                    logMessage += "[\(timestamp)] AppState available, loading file: \(url.path)\n"
                    DispatchQueue.main.async {
                        appState.loadFile(at: url)
                    }
                } else {
                    logMessage += "[\(timestamp)] AppState not ready, storing URL: \(url.path)\n"
                    pendingURLs.append(url)
                    // Start retry timer if not already running
                    startRetryTimer()
                }
                break
            }
        }
        
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logPath)
            }
        }
    }
    
    func processPendingURLs() {
        print("📦 processPendingURLs called. AppState: \(appState != nil ? "available" : "nil"), pending count: \(pendingURLs.count)")
        
        // Log to file
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
        let timestamp = Date().description
        let logMessage = "[\(timestamp)] processPendingURLs: appState=\(appState != nil ? "available" : "nil"), pending=\(pendingURLs.count)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logPath)
            }
        }
        
        guard let appState = appState else { 
            print("⚠️ AppState still not available in processPendingURLs")
            return 
        }
        
        for url in pendingURLs {
            print("📂 Processing pending URL: \(url.path)")
            DispatchQueue.main.async {
                appState.loadFile(at: url)
            }
        }
        pendingURLs.removeAll()
    }
}

// @main attribute marks this as the entry point for the application
// In Swift, @ symbols denote attributes - metadata that provides information about declarations
@main
struct ParqViewApp: App {
    // @StateObject creates and owns an observable object that persists for the lifetime of the view
    // We use this for app-wide state management
    @StateObject private var appState = AppState()
    
    // Use NSApplicationDelegateAdaptor to connect our custom AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("🚀 ParqViewApp initialized")
        
        // Also log to a file for debugging
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
        let timestamp = Date().description
        let logMessage = "[\(timestamp)] ParqViewApp initialized\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
    }
    
    // The 'body' property is required by the App protocol
    // 'some Scene' is an opaque return type - the compiler knows the exact type but we don't need to specify it
    var body: some Scene {
        // WindowGroup creates the main application window
        // It handles window management for us (creating, closing, multiple windows on macOS)
        WindowGroup {
            ImprovedMainView()
                .environmentObject(appState) // Makes appState available to all child views
                .frame(minWidth: 900, minHeight: 600)
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"]) // Handle all file open events
                .onDisappear {
                    // Reset state when window closes
                    print("🔄 Window closing, resetting state")
                    appState.currentFile = nil
                    appState.errorMessage = nil
                    appState.isLoading = false
                }
                .onAppear {
                    // Connect appDelegate to appState
                    appDelegate.appState = appState
                    print("✅ Connected appDelegate to appState in onAppear")
                    
                    // Log to file
                    let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
                    let timestamp = Date().description
                    let logMessage = "[\(timestamp)] Connected appDelegate to appState in onAppear\n"
                    
                    if let data = logMessage.data(using: .utf8) {
                        if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    }
                    
                    // Ensure the app is active and can receive keyboard input
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        // Make sure the window becomes key window
                        for window in NSApplication.shared.windows {
                            if window.isVisible {
                                window.makeKeyAndOrderFront(nil)
                                window.level = .normal
                                window.collectionBehavior = [.managed, .fullScreenPrimary]
                                break
                            }
                        }
                        // Check if there's a pending file to open
                        appState.checkPendingFile()
                        // Also check AppDelegate pending URLs (in case they weren't processed yet)
                        appDelegate.processPendingURLs()
                    }
                }
                .onOpenURL { url in
                    // Handle files opened from Finder
                    print("📂 onOpenURL called with: \(url.path)")
                    
                    // Log to file
                    let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
                    let timestamp = Date().description
                    let logMessage = "[\(timestamp)] onOpenURL called with: \(url.path)\n"
                    
                    if let data = logMessage.data(using: .utf8) {
                        if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    }
                    
                    appState.loadFile(at: url, defer: true)
                }
        }
        .commands {
            // Add custom menu commands here
            CommandGroup(replacing: .newItem) {
                Button("Open Parquet File...") {
                    appState.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            // Ensure standard keyboard shortcuts work
            CommandGroup(after: .appTermination) {
                Button("Quit ParqView") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
        
        // Settings window for preferences
        Settings {
            SettingsView()
        }
    }
}

// Observable object pattern for app-wide state
// @MainActor ensures all UI updates happen on the main thread
@MainActor
class AppState: ObservableObject {
    // @Published makes SwiftUI views automatically update when this changes
    @Published var currentFile: ParquetFile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var fileLoadID = UUID()  // Changes every time a new file is loaded
    
    // Store pending file URL if it arrives before view is ready
    private var pendingFileURL: URL?
    
    init() {
        // Connect to AppDelegate if it exists
        if let appDelegate = AppDelegate.shared {
            appDelegate.appState = self
            print("✅ Connected AppState to AppDelegate in init")
            
            // Log to file
            let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
            let timestamp = Date().description
            let logMessage = "[\(timestamp)] Connected AppState to AppDelegate in init\n"
            
            if let data = logMessage.data(using: .utf8) {
                if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    try? data.write(to: logPath)
                }
            }
            
            // Process any pending URLs
            appDelegate.processPendingURLs()
        }
    }
    
    func openDocument() {
        let panel = NSOpenPanel()
        // Support both .parquet and .parq extensions
        let parquetType = UTType(filenameExtension: "parquet") ?? .data
        let parqType = UTType(filenameExtension: "parq") ?? .data
        panel.allowedContentTypes = [parquetType, parqType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                loadFile(at: url)
            }
        }
    }
    
    func loadFile(at url: URL, defer deferIfNotReady: Bool = false) {
        print("🔄 loadFile called with URL: \(url.path)")
        print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
        print("   Extension: \(url.pathExtension)")
        
        // Log to file
        logToFile("loadFile called with: \(url.path), exists: \(FileManager.default.fileExists(atPath: url.path)), defer: \(deferIfNotReady)")
        
        // If we should defer and the app isn't ready, store for later
        if deferIfNotReady && !isAppReady() {
            print("⏳ App not ready, storing URL for later: \(url.path)")
            logToFile("App not ready, deferring file: \(url.path)")
            pendingFileURL = url
            return
        }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            // Clear current file immediately to reset UI
            await MainActor.run {
                self.currentFile = nil
            }
            
            do {
                // Check if file exists
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("❌ File not found at path: \(url.path)")
                    throw NSError(domain: "ParqView", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "File not found at path: \(url.lastPathComponent)"
                    ])
                }
                
                // Check file extension
                let validExtensions = ["parquet", "parq"]
                guard validExtensions.contains(url.pathExtension.lowercased()) else {
                    print("❌ Invalid extension: \(url.pathExtension)")
                    throw NSError(domain: "ParqView", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid file type. ParqView supports .parquet and .parq files."
                    ])
                }
                
                print("✅ Loading file with ParquetFile.load...")
                logToFile("Loading file with ParquetFile.load...")
                // This will use SharedCore to load the file
                let file = try await ParquetFile.load(from: url)
                print("✅ File loaded successfully: \(file.schema.columns.count) columns, \(file.totalRows) rows")
                logToFile("File loaded successfully: \(file.schema.columns.count) columns, \(file.totalRows) rows")
                
                // Ensure UI update happens on main thread
                await MainActor.run {
                    self.currentFile = file
                    print("✅ currentFile set on MainActor - UI should update now")
                    logToFile("currentFile set on MainActor - UI should update now")
                }
            } catch let error as NSError {
                print("❌ NSError: \(error.localizedDescription)")
                logToFile("NSError loading file: \(error.localizedDescription)")
                // Use custom error message if available
                errorMessage = error.localizedDescription
            } catch {
                print("❌ Error: \(error)")
                logToFile("Error loading file: \(error)")
                // Provide more specific error messages
                let message: String
                if error.localizedDescription.contains("arrow") || error.localizedDescription.contains("parquet") {
                    message = "Failed to read Parquet file. The file may be corrupted or use an unsupported format."
                } else {
                    message = "Failed to load file: \(error.localizedDescription)"
                }
                errorMessage = message
            }
            
            isLoading = false
            print("🏁 loadFile completed. isLoading=\(isLoading), currentFile=\(currentFile != nil ? "SET" : "nil")")
            logToFile("loadFile completed. isLoading=\(isLoading), currentFile=\(currentFile != nil ? "SET" : "nil"), error=\(errorMessage ?? "none")")
        }
    }
    
    private func isAppReady() -> Bool {
        // Check if we have an active window
        return NSApplication.shared.windows.contains { $0.isVisible }
    }
    
    func checkPendingFile() {
        if let url = pendingFileURL {
            print("📁 Processing pending file: \(url.path)")
            logToFile("Processing pending file: \(url.path)")
            pendingFileURL = nil
            loadFile(at: url)
        }
    }
    
    private func logToFile(_ message: String) {
        let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("parqview_debug.log")
        let timestamp = Date().description
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logPath)
            }
        }
    }
}