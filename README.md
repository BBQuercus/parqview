# ParqView

A native macOS app for viewing Parquet files.

[![Build](https://github.com/BBQuercus/parqview/actions/workflows/build.yml/badge.svg)](https://github.com/BBQuercus/parqview/actions/workflows/build.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Download

**[Download Latest Release](https://github.com/BBQuercus/parqview/releases/latest)**

Or grab development builds from [Actions](https://github.com/BBQuercus/parqview/actions) (click latest run > Artifacts).

### First Launch
Since the app isn't notarized with Apple, macOS will show a security warning. Use one of these methods:

**Option 1: Right-click method**
1. Right-click (or Control+click) on ParqView.app
2. Select "Open" from the menu
3. Click "Open" in the dialog

**Option 2: System Settings**
1. Try to open the app normally (it will be blocked)
2. Go to **System Settings → Privacy & Security**
3. Scroll down to find "ParqView was blocked"
4. Click **"Open Anyway"**

**Option 3: Terminal**
```bash
xattr -cr /Applications/ParqView.app
```

This is a one-time requirement. After opening it once, macOS will remember your choice.

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
- Apple Silicon Mac (ARM64) - Intel builds coming soon
- Apache Arrow libraries: `brew install apache-arrow`

## License

MIT
