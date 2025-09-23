# ParqView Project Guide

## Project Overview
ParqView is a native macOS application for viewing and querying Parquet files. It provides:
- Full viewer application with schema browsing, data viewing, and SQL querying
- Native performance using C++ libraries (Arrow/Parquet and DuckDB)

## Architecture

### Technology Stack
- **UI Framework**: SwiftUI (modern declarative UI framework for Apple platforms)
- **Language**: Swift 5.9+ with C++ interop for performance-critical parts
- **Data Processing**: Apache Arrow C++ (schema/sampling) + DuckDB (full queries)
- **Build System**: Swift Package Manager (SPM)
- **Deployment**: Signed .dmg with notarization

### Project Structure
```
ParqView/
├── Package.swift                 # SPM manifest defining targets and dependencies
├── Sources/
│   ├── ParqViewApp/             # Main application
│   │   ├── ParqViewApp.swift   # App entry point (@main)
│   │   └── Views/               # SwiftUI views
│   └── SharedCore/              # Shared framework
│       ├── Models/              # Data models
│       ├── Bridge/              # C++ interop layer
│       └── Services/            # Business logic
└── Tests/                       # Unit tests
```

## Swift Concepts for Beginners

### Key Swift/SwiftUI Patterns Used

1. **@main attribute**: Marks the app entry point
   - Similar to `main()` in other languages
   - SwiftUI apps use `App` protocol

2. **Property Wrappers** (@ symbols):
   - `@State`: View-local mutable state
   - `@StateObject`: Creates and owns an ObservableObject
   - `@ObservedObject`: References an external ObservableObject
   - `@EnvironmentObject`: Dependency injection through view hierarchy
   - `@Binding`: Two-way connection to a state value
   - `@AppStorage`: Persistent storage in UserDefaults

3. **View Protocol**: All UI components conform to View
   - `body` property returns the view content
   - Views are structs (value types) for performance

4. **ObservableObject Pattern**: For shared state
   - Classes conforming to ObservableObject
   - `@Published` properties trigger UI updates
   - Used with @StateObject/@ObservedObject

5. **Async/Await**: Modern concurrency
   - `async` functions can be awaited
   - `Task` creates concurrent work
   - `@MainActor` ensures UI updates on main thread

## Building and Running

### Prerequisites
1. Xcode 15+ or Swift 5.9+ toolchain
2. macOS Ventura (13.0) or later

### Build Commands
```bash
# Build the project
swift build

# Run the app
swift run ParqViewApp

# Run tests
swift test

# Build for release
swift build -c release
```

### Opening in Xcode
```bash
# Generate Xcode project (optional, SPM projects open directly)
open Package.swift
# Or double-click Package.swift in Finder
```

## Key Implementation Notes

### C++ Integration Strategy
1. **SharedCore** contains Swift wrappers around C++ code
2. **ParquetBridge.swift** provides Swift-friendly API
3. C++ implementation will be in `Sources/SharedCore/cpp/`
4. Use bridging header for C++ ↔ Swift interop

### Data Flow
1. **File Opening**: User selects file → AppState.loadFile() → SharedCore reads schema/metadata
2. **Table Display**: TableViewerView requests pages → DuckDBService executes paginated queries

### Performance Considerations
- Use lazy loading for large files (LazyVStack)
- Pagination for table data (load on scroll)
- DuckDB for efficient queries without loading entire file
- Arrow for fast schema/metadata reading

## Next Steps for Implementation

### Phase 1: Basic Functionality ✅
- [x] Project structure
- [x] Main app UI skeleton
- [x] Data models
- [x] Mock implementations

### Phase 2: C++ Integration
- [ ] Add Arrow C++ library via SPM or CMake
- [ ] Implement ParquetBridge C++ backend
- [ ] Add DuckDB library
- [ ] Implement DuckDBService backend

### Phase 3: File Association & Distribution
- [ ] Configure Info.plist for .parquet files
- [ ] Add app icon and assets
- [ ] Set up code signing
- [ ] Create .dmg packaging script

### Phase 4: Polish
- [ ] Error handling and recovery
- [ ] Performance optimization
- [ ] Keyboard shortcuts
- [ ] Export functionality
- [ ] Column statistics view

## Common Tasks

### Adding a New View
1. Create new file in `Sources/ParqViewApp/Views/`
2. Define struct conforming to View protocol
3. Implement `body` property
4. Wire up navigation or presentation

### Adding C++ Code
1. Add .cpp/.h files to `Sources/SharedCore/cpp/`
2. Update bridging header
3. Create Swift wrapper in `Bridge/`
4. Expose through public API

### Testing
1. Add test file to appropriate Tests/ subdirectory
2. Import module with `@testable import ModuleName`
3. Write XCTestCase subclass
4. Run with `swift test`

## Troubleshooting

### Common Issues
1. **"No such module" error**: Run `swift build` first
2. **C++ linking errors**: Check bridging header and CMake config
3. **UI not updating**: Ensure @Published properties and proper observation
4. **File access denied**: Check sandbox entitlements for file access

### Debug Tips
- Use `print()` for console output
- Set breakpoints in Xcode
- Use `LLDB` commands: `po variable` to print objects
- Check `Console.app` for system logs

## Resources
- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [DuckDB C API](https://duckdb.org/docs/api/c/overview)
- [Apache Arrow C++](https://arrow.apache.org/docs/cpp/)
- Use uv for everything. I already set up a virtualenv