import SwiftUI
import SharedCore
import UniformTypeIdentifiers
import AppKit
import os.log

private let logger = Logger(subsystem: "com.parqview.ParqView", category: "App")

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
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.setActivationPolicy(.regular)
        startRetryTimer()

        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.unhide(nil)
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.debug("applicationDidFinishLaunching - Windows: \(NSApplication.shared.windows.count)")
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            if NSApplication.shared.windows.isEmpty {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.setActivationPolicy(.regular)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.center()
                        window.makeMain()
                    }
                }
            } else if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.center()
                window.makeMain()
                if !window.isVisible {
                    window.setIsVisible(true)
                }
            }

            NSApplication.shared.activate(ignoringOtherApps: true)
            if NSApplication.shared.isHidden {
                NSApplication.shared.unhide(nil)
            }
        }

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.retryTimer?.invalidate()
            self?.retryTimer = nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        logger.debug("application:open: called with \(urls.count) URLs")

        if NSApplication.shared.windows.isEmpty {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.setActivationPolicy(.regular)
        }

        // Process all valid parquet files, not just the first one
        let parquetURLs = urls.filter { ["parquet", "parq"].contains($0.pathExtension.lowercased()) }

        for url in parquetURLs {
            if let appState = appState {
                logger.debug("Loading file: \(url.path)")
                DispatchQueue.main.async {
                    appState.loadFile(at: url)
                }
                break // Load only the first file for now
            } else {
                logger.debug("AppState not ready, queuing: \(url.path)")
                pendingURLs.append(url)
                startRetryTimer()
                break
            }
        }

        if parquetURLs.isEmpty && !urls.isEmpty {
            logger.warning("No valid parquet files in opened URLs")
        }
    }

    func processPendingURLs() {
        logger.debug("processPendingURLs: pending=\(self.pendingURLs.count)")

        guard let appState = appState else {
            logger.debug("AppState not available yet")
            return
        }

        // Process only the first pending URL
        if let url = pendingURLs.first {
            logger.debug("Processing pending: \(url.path)")
            DispatchQueue.main.async {
                appState.loadFile(at: url)
            }
        }
        pendingURLs.removeAll()
    }
}

@main
struct ParqViewApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ImprovedMainView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .onDisappear {
                    appState.currentFile = nil
                    appState.errorMessage = nil
                    appState.isLoading = false
                }
                .onAppear {
                    appDelegate.appState = appState
                    logger.debug("Connected appDelegate to appState")

                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        for window in NSApplication.shared.windows where window.isVisible {
                            window.makeKeyAndOrderFront(nil)
                            window.level = .normal
                            window.collectionBehavior = [.managed, .fullScreenPrimary]
                            break
                        }
                        appState.checkPendingFile()
                        appDelegate.processPendingURLs()
                    }
                }
                .onOpenURL { url in
                    logger.debug("onOpenURL: \(url.path)")
                    appState.loadFile(at: url, defer: true)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Parquet File...") {
                    appState.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var currentFile: ParquetFile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var fileLoadID = UUID()

    private var pendingFileURL: URL?

    init() {
        if let appDelegate = AppDelegate.shared {
            appDelegate.appState = self
            logger.debug("Connected AppState to AppDelegate")
            appDelegate.processPendingURLs()
        }
    }

    func openDocument() {
        let panel = NSOpenPanel()
        let parquetType = UTType(filenameExtension: "parquet") ?? .data
        let parqType = UTType(filenameExtension: "parq") ?? .data
        panel.allowedContentTypes = [parquetType, parqType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(at: url)
        }
    }

    func loadFile(at url: URL, defer deferIfNotReady: Bool = false) {
        logger.debug("loadFile: \(url.path)")

        if deferIfNotReady && !isAppReady() {
            logger.debug("App not ready, deferring: \(url.path)")
            pendingFileURL = url
            return
        }

        Task {
            isLoading = true
            errorMessage = nil

            await MainActor.run {
                self.currentFile = nil
            }

            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ParquetError.fileNotFound(url.path)
                }

                let validExtensions = ["parquet", "parq"]
                guard validExtensions.contains(url.pathExtension.lowercased()) else {
                    throw ParquetError.invalidFormat("Invalid file type. Expected .parquet or .parq")
                }

                let file = try await ParquetFile.load(from: url)
                logger.info("Loaded: \(file.schema.columns.count) cols, \(file.totalRows) rows")

                await MainActor.run {
                    self.currentFile = file
                    self.fileLoadID = UUID()
                }
            } catch {
                logger.error("Load failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func isAppReady() -> Bool {
        return NSApplication.shared.windows.contains { $0.isVisible }
    }

    func checkPendingFile() {
        if let url = pendingFileURL {
            logger.debug("Processing pending: \(url.path)")
            pendingFileURL = nil
            loadFile(at: url)
        }
    }
}
