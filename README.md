# ParqView

A native macOS app for viewing Parquet files.

[![Build](https://github.com/BBQuercus/parqview/actions/workflows/build.yml/badge.svg)](https://github.com/BBQuercus/parqview/actions/workflows/build.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Download

**[Download Latest Release](https://github.com/BBQuercus/parqview/releases/latest)**

Or grab development builds from [Actions](https://github.com/BBQuercus/parqview/actions) (click latest run > Artifacts).

### First Launch
Since the app isn't code-signed, macOS will block it:
1. Right-click the app > "Open"
2. Click "Open" in the dialog

## Features

- View Parquet file schemas and metadata
- Browse data with pagination
- Filter data across all columns
- Native macOS experience (SwiftUI)
- Fast C++ backend (Apache Arrow)

## Usage

Open `.parquet` files by:
- Double-clicking them
- Dragging onto the app
- File > Open

## Building from Source

```bash
# Install dependencies
brew install apache-arrow

# Build
swift build -c release

# Or build the app bundle
./Scripts/build_app.sh
open .build/ParqView.app
```

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## License

MIT
