#!/bin/bash
set -e

echo "Building EmaxForge v0.5 Beta Release..."

# Clean previous build
rm -rf .build/release/EmaxForge.app
rm -rf EmaxForge-v0.5-beta.zip

# Build release
echo "Compiling Swift..."
swift build -c release

# Check if binary exists
if [[ ! -f ".build/release/EmaxForge" ]]; then
    echo "Build failed - binary not found"
    exit 1
fi

echo "Build complete: .build/release/EmaxForge"

# Create .app bundle
echo "Creating .app bundle..."
BUNDLE_DIR="EmaxForge.app"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
cp .build/release/EmaxForge "$BUNDLE_DIR/Contents/MacOS/"

# Copy essential resources only (skip backups, originals, broken files, and large EZ2 templates)
if [[ -d "EmaxForge/Resources" ]]; then
    find EmaxForge/Resources -maxdepth 1 -type f \
        ! -name "*.backup" \
        ! -name "*.ORIGINAL" \
        ! -name "*.BROKEN" \
        ! -name "*.OLD*" \
        -exec cp {} "$BUNDLE_DIR/Contents/Resources/" \;
    # Copy bootable_templates dir, skipping backups and large templates
    if [[ -d "EmaxForge/Resources/bootable_templates" ]]; then
        mkdir -p "$BUNDLE_DIR/Contents/Resources/bootable_templates"
        find EmaxForge/Resources/bootable_templates -maxdepth 1 -type f \
            ! -name "*.backup" \
            ! -name "*.ORIGINAL" \
            -exec cp {} "$BUNDLE_DIR/Contents/Resources/bootable_templates/" \;
    fi
fi

# Create Info.plist
cat > "$BUNDLE_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>EmaxForge</string>
    <key>CFBundleIdentifier</key>
    <string>com.emaxforge.app</string>
    <key>CFBundleName</key>
    <string>EmaxForge</string>
    <key>CFBundleVersion</key>
    <string>0.5</string>
    <key>CFBundleShortVersionString</key>
    <string>0.5-beta</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ".app bundle created: $BUNDLE_DIR"

# Create distributable ZIP
echo "Creating distribution archive..."
zip -r EmaxForge-v0.5-beta.zip EmaxForge.app

echo "Release package: EmaxForge-v0.5-beta.zip"
echo ""
ls -lh EmaxForge-v0.5-beta.zip

# Generate checksums
echo ""
echo "Checksums:"
shasum -a 256 EmaxForge-v0.5-beta.zip | tee CHECKSUMS.txt

echo ""
echo "Release build complete!"
echo ""
echo "Next steps:"
echo "  1. Test: open EmaxForge.app"
echo "  2. Upload: EmaxForge-v0.5-beta.zip to GitHub releases"
echo "  3. Copy release notes from .github/RELEASE_DRAFT.md"
