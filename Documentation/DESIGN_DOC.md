📄 Design Document – ParqView

1. Overview

ParqView is a macOS-only application providing a full viewer for Parquet files. It's a standalone macOS app that loads Parquet files, allowing browsing, filtering, and basic SQL querying.

The goal is to give macOS users a native, fast, and intuitive way to inspect Parquet files without requiring Python, Spark, or heavy tooling.

2. Goals & Non-Goals

Goals
• Native macOS .app and .dmg distribution (not App Store).
• Full viewer app with:
• Schema browser
• Table viewer with infinite scroll
• Basic filtering/sorting
• SQL query interface (DuckDB backend)

Non-Goals (v1)
• Editing/writing Parquet files
• Cross-platform support (Windows/Linux)
• Complex visualization/analytics beyond table + schema

3. Architecture

High-Level

```
                           +------------------------+
                           | ParqView App           |
                           |------------------------|
                           | SwiftUI App            |
                           | - SchemaView           |
                           | - TableViewerView      |
                           | - QueryView (DuckDB)   |
                           +-----------+------------+
                                       |
                                       v
       +------------ SharedCore (Arrow/Parquet) ------------+
       | - Arrow C++ reader (schema + sample rows)          |
       | - Swift ↔ C++ bridge (SwiftBridge.swift)           |
       +----------------------------------------------------+
                                  |
                                  v
                          +---------------+
                          | DuckDB engine |
                          | - Full parquet |
                          |   load/query    |
                          +----------------+
```

4. Components

4.1 Main App (ParqViewApp)
• Framework: SwiftUI
• Views:
• SchemaView → Column names, types, metadata
• TableViewerView → Scrollable table, paging via DuckDB
• QueryView → SQL editor, run queries via DuckDBService
• Backend:
• DuckDBService → Wraps DuckDB C API for queries/filters
• Uses SharedCore for schema/sample extraction

4.2 SharedCore
• Language: C++ + Swift bridge
• Responsibilities:
• Read schema from parquet
• Extract first N rows efficiently
• Expose results via Swift structs

4.3 Distribution
• Signed .dmg containing app
• Notarized with Apple to avoid Gatekeeper warnings

5. Dependencies
   • Apache Arrow / parquet-cpp → Schema + row sampling
   • DuckDB → Full file reading, queries, sorting, filtering
   • SwiftUI → UI framework
   • Combine → Data binding (async query results to UI)

6. UX Flow

Viewer App 1. User double-clicks .parquet file → opens in ParqView 2. Main window:
• Left panel: Schema
• Right panel: Table viewer (scrollable, lazy-loaded from DuckDB)
• Bottom panel: SQL query box + results

7. Roadmap

MVP (v1.0)
• Full app: schema view, full file viewer, basic DuckDB query

Future Enhancements
• Multi-file/dataset support
• Export subset to CSV/JSON
• Column statistics (min/max/distinct count)
• Keyboard shortcuts (jump to column, quick filter)

8. Risks & Mitigation
   • C++ integration complexity → Use minimal Arrow APIs + C bridging layer
   • App signing/notarization → Test early with Developer ID
   • Performance on large files → Use DuckDB lazy loading & filtering pushdown
   • User expectations → Keep UX lightweight (not a full data IDE)
