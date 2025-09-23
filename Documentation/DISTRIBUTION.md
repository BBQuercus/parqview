# ParqView Distribution Guide

## Build Status
✅ **Universal Binary**: Supports both Intel and Apple Silicon Macs
✅ **DMG Installer**: Professional distribution format
✅ **Icon**: Custom app icon with macOS design guidelines
✅ **Minimum macOS**: 13.0 (Ventura)

## Quick Distribution

### For Personal/Testing Distribution
```bash
# Build universal app with DMG
./build_distribution.sh --dmg

# The DMG file (ParqView.dmg) is ready to share
```

### For Public Distribution (Requires Apple Developer Account)
```bash
# Build, sign, and create DMG
./build_distribution.sh --sign --developer-id "Your Developer ID" --dmg

# For App Store distribution, also notarize:
./build_distribution.sh --sign --notarize --dmg
```

## Distribution Files

- **ParqView.dmg** (2.1MB) - Disk image for easy installation
- **.build/ParqView.app** - The app bundle itself

## System Requirements

### For End Users
- **macOS**: 13.0 (Ventura) or later
- **Architecture**: Intel or Apple Silicon
- **Dependencies**: Apache Arrow libraries
  ```bash
  # Users need to install:
  brew install apache-arrow
  ```

### Known Limitations
1. **Library Dependencies**: Users must have Arrow/Parquet libraries installed via Homebrew
2. **Security Warning**: Without code signing, users will see a security warning on first launch
   - Solution: Right-click the app and select "Open"
   - Or: Go to System Settings > Privacy & Security to allow

## Code Signing (Optional but Recommended)

### Benefits of Code Signing
- No security warnings for users
- Can be notarized for additional trust
- Required for Mac App Store distribution

### How to Sign
1. Get an Apple Developer account ($99/year)
2. Create a Developer ID certificate
3. Use the distribution script:
   ```bash
   ./build_distribution.sh --sign --developer-id "Developer ID Application: Your Name"
   ```

## Distribution Checklist

### Before Distribution
- [x] Universal binary (Intel + Apple Silicon)
- [x] App icon configured
- [x] Info.plist with proper metadata
- [x] File type associations (.parquet, .parq)
- [ ] Code signing (optional but recommended)
- [ ] Notarization (optional, requires signing)

### Testing
1. Test on Apple Silicon Mac ✓
2. Test on Intel Mac (if available)
3. Test file associations (double-click .parquet files)
4. Test without Arrow libraries (shows appropriate error)

### Distribution Methods

#### Method 1: Direct DMG (Current)
- Share `ParqView.dmg`
- Users drag app to Applications folder
- Simple but requires dependency installation

#### Method 2: Homebrew Cask (Future)
```ruby
# Future homebrew-cask formula
cask "parqview" do
  version "1.0.0"
  sha256 "..."
  
  url "https://github.com/yourusername/parqview/releases/download/v#{version}/ParqView.dmg"
  name "ParqView"
  desc "Native macOS viewer for Parquet files"
  
  depends_on formula: "apache-arrow"
  
  app "ParqView.app"
end
```

#### Method 3: Mac App Store (Future)
- Requires sandboxing modifications
- Need to bundle or remove C++ dependencies
- Requires Apple Developer Program

## Troubleshooting

### "App is damaged and can't be opened"
- App needs to be signed or allowed in Security settings
- Solution: `xattr -cr /Applications/ParqView.app`

### "Library not loaded: libarrow.dylib"
- Arrow libraries not installed
- Solution: `brew install apache-arrow`

### App doesn't open on older macOS
- Requires macOS 13.0 (Ventura) or later
- Check with: `sw_vers -productVersion`

## Current Architecture Support

The app is built as a **universal binary** supporting:
- ✅ Apple Silicon (M1/M2/M3) - Native
- ✅ Intel x86_64 - Native

Binary info:
```
Architectures: x86_64 arm64
Size: ~3.1MB (app), ~2.1MB (DMG)
```

## Future Improvements

1. **Bundle Dependencies**: Include Arrow libraries in app bundle
2. **Auto-updater**: Sparkle framework for updates  
3. **Homebrew Formula**: Easier installation for developers
4. **App Store**: Wider distribution (requires more work)

## Release Process

1. Update version in Info.plist
2. Run tests: `swift test`
3. Build distribution: `./build_distribution.sh --dmg`
4. Test DMG on clean system
5. Create GitHub release with DMG attached
6. Update download links in README

## Support

For distribution issues, please file an issue on GitHub with:
- macOS version
- Processor type (Intel/Apple Silicon)
- Error messages or screenshots
- Installation method used