# Release Checklist

## Pre-Release
- [ ] Update version in Info.plist
- [ ] Update README with new features
- [ ] Run tests: `swift test`
- [ ] Test on Apple Silicon Mac
- [ ] Test on Intel Mac (if available)
- [ ] Verify file associations work

## Build
- [ ] Clean build directory: `rm -rf .build`
- [ ] Build distribution: `./build_distribution.sh --dmg`
- [ ] Verify universal binary: `lipo -info .build/ParqView.app/Contents/MacOS/ParqView`
- [ ] Check bundled dependencies: `otool -L .build/ParqView.app/Contents/MacOS/ParqView`
- [ ] Test DMG installation

## GitHub Release
- [ ] Create git tag: `git tag v1.0.0`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Wait for CI/CD to complete
- [ ] Verify release was created
- [ ] Download and test released DMG

## Post-Release
- [ ] Share on social media
- [ ] Update Homebrew formula (if applicable)
- [ ] Monitor issues for bug reports

## Release Info
- **DMG Size**: ~8.4MB (with bundled dependencies)
- **App Size**: ~27MB installed
- **Architectures**: Universal (Intel + Apple Silicon)
- **Min macOS**: 13.0 (Ventura)
- **Dependencies**: All bundled! No installation needed

## Known Issues for v1.0.0
- App is not code-signed (users need to right-click → Open)
- SQL error messages could be more helpful
- The entire codebase was AI-generated (vibe-coded)

## Testing Commands
```bash
# Build everything
./build_distribution.sh --dmg

# Test the app
open .build/ParqView.app

# Check bundling
otool -L .build/ParqView.app/Contents/MacOS/ParqView | grep "@executable_path"

# Verify universal binary
file .build/ParqView.app/Contents/MacOS/ParqView
```

## Distribution Notes
The app now includes all dependencies bundled, so users don't need to install anything!