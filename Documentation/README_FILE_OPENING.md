# ParqView File Opening from Finder - Solution

## Problem
When opening a .parquet file from Finder (double-click or Open With), ParqView would launch but not load the file.

## Root Cause
The initial implementation used `onOpenURL` which is primarily for custom URL schemes, not for file opening on macOS. When macOS launches an app to open a file, it uses the NSApplicationDelegate's `application(_:open:)` method.

## Solution
Added proper file handling using NSApplicationDelegate:

1. **Created AppDelegate class** that implements NSApplicationDelegate
2. **Implemented `application(_:open:)` method** to handle file URLs from Finder
3. **Connected AppDelegate to App using @NSApplicationDelegateAdaptor**
4. **Connected AppDelegate to AppState** to enable file loading

## Key Code Changes

### ParqViewApp.swift
```swift
// Custom AppDelegate to handle file opening from Finder
class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle files opened from Finder
        for url in urls {
            if ["parquet", "parq"].contains(url.pathExtension.lowercased()) {
                DispatchQueue.main.async { [weak self] in
                    self?.appState?.loadFile(at: url)
                }
                break
            }
        }
    }
}

@main
struct ParqViewApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // In body's onAppear:
    .onAppear {
        // Connect appDelegate to appState
        appDelegate.appState = appState
        // ... rest of onAppear code
    }
}
```

## Build and Install Process

Use the provided scripts to build and install:

```bash
# Build and install to /Applications
./build_and_install.sh

# Test the installation
./test_app.sh
```

## Testing File Opening

After installation, you can test file opening in multiple ways:

1. **Double-click** a .parquet file in Finder
2. **Right-click** → Open With → ParqView
3. **Command line**: `open -a ParqView file.parquet`
4. **Drag and drop** onto the app icon or window

## Debug Logging

Debug logs are written to `~/parqview_debug.log` and include:
- App initialization
- File URL reception
- File loading progress
- Success/error messages

To monitor logs in real-time:
```bash
tail -f ~/parqview_debug.log
```

## Important Notes

1. The app must be properly installed in /Applications for file associations to work
2. Launch Services database is reset during installation to ensure proper registration
3. The Info.plist must declare the supported file types (already configured)
4. Code signing is applied during the build process for proper macOS integration