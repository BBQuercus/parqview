# ParqView 🦜

A native macOS application for viewing and querying Apache Parquet files.

> ⚠️ **DISCLAIMER**: This entire application was vibe-coded with claude-code and was to solve a problem I had while working as data scientist and not as MacOS developer. While functional, it may contain bugs, inefficiencies, or unconventional patterns. Use at your own risk and feel free to contribute improvements!

[![Build and Release](https://github.com/yourusername/parqview/actions/workflows/release.yml/badge.svg)](https://github.com/yourusername/parqview/actions/workflows/release.yml)
![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Vibe Coded](https://img.shields.io/badge/vibe-coded-ff69b4)

## Features

- 📊 **Schema Viewer**: Instantly view Parquet file structure and metadata
- 📖 **Data Browser**: Navigate through data with smooth pagination
- 🔍 **SQL Queries**: Run SQL queries using embedded DuckDB
- 🖥️ **Native macOS**: Built with SwiftUI for that buttery smooth Mac experience
- 🏃 **Fast**: C++ powered with Apache Arrow for maximum performance
- 🎨 **Clean UI**: Minimalist design that follows macOS guidelines

## Installation

### Quick Install (Recommended)
1. Download the latest `ParqView.dmg` from [Releases](https://github.com/bbquercus/parqview/releases)
2. Open the DMG and drag ParqView to your Applications folder
3. On first launch, right-click and select "Open" (app is not code-signed yet)

### Requirements
- macOS 13.0 (Ventura) or later
- Works on both Intel and Apple Silicon Macs
- Dependencies are bundled! (No more `brew install` needed)

## Usage

### Opening Files
- **Double-click** any `.parquet` or `.parq` file
- **Drag & drop** files onto the app icon
- Use **File → Open** from the menu

### Viewing Data
- Schema tab shows column names, types, and metadata
- Data tab displays paginated content
- Use arrow keys or buttons to navigate pages

### SQL Queries
Click the Query button to write SQL:
```sql
-- Your file is automatically available as 'parquet' table
SELECT * FROM parquet WHERE price > 100 LIMIT 50;

-- Aggregations work too!
SELECT category, COUNT(*), AVG(price) 
FROM parquet 
GROUP BY category;
```

## Building from Source

### Prerequisites
```bash
# Install build dependencies
brew install apache-arrow
brew install python3
pip3 install Pillow  # For icon generation
```

### Build Steps
```bash
# Clone the repository
git clone https://github.com/yourusername/parqview.git
cd parqview

# Quick build for local use
./build_app.sh

# Or build distribution with universal binary
./build_distribution.sh --dmg

# Run the app
open .build/ParqView.app
```

### Development
```bash
# Open in Xcode
open Package.swift

# Run tests
swift test

# Build and run
swift run ParqViewApp
```

## Architecture

Built with modern macOS technologies:
- **SwiftUI** - Native UI framework
- **Apache Arrow C++** - High-performance Parquet reading
- **DuckDB** - Embedded SQL engine
- **Swift/C++ Interop** - Bridging for maximum performance

See [DESIGN_DOC.md](DESIGN_DOC.md) for architecture details.

## The Vibe-Coding Story 🌊

This app was built entirely through conversation with AI:
- No manual coding, just vibes and prompts
- Architecture designed through discussion
- Every line generated from natural language
- Bugs included at no extra charge!

Despite (or because of?) this approach, it actually works pretty well!

## Contributing

Found a bug? Not surprised! Feel free to:
- Open an issue
- Submit a PR
- Rewrite everything properly
- Share your own vibe-coded improvements

## Distribution

See [DISTRIBUTION.md](DISTRIBUTION.md) for:
- Building release versions
- Code signing instructions
- Creating DMG installers
- CI/CD setup

## Known Limitations

- Not code-signed (security warnings on first launch)
- Some C++ dependencies might act weird
- SQL errors could be more helpful
- The whole thing was AI-generated so... 🤷

## Future Ideas

- [ ] Column statistics and profiling
- [ ] Export to CSV/JSON
- [ ] Dark mode improvements
- [ ] Actual human code review
- [ ] Sparkle auto-updater
- [ ] Mac App Store release (eventually)

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

*Made with ❤️, AI, and questionable engineering practices*

*If this actually works for you, I'm as surprised as you are!*
