#!/bin/bash
set -e

echo "🔨 Building EmaxForge..."

# Clean previous build
rm -rf .build/EmaxForge.app

# Build with Swift Package Manager (warnings cause exit 1, but that's ok)
echo "Building for production..."
swift build -c release || true

# Check if binary was actually built
if [ ! -f ".build/release/emaxforge" ]; then
    echo "❌ Build failed - binary not found!"
    exit 1
fi

# Create .app bundle structure
mkdir -p .build/EmaxForge.app/Contents/MacOS
mkdir -p .build/EmaxForge.app/Contents/Resources

# Copy binary (swift produces lowercase binary name)
cp .build/release/emaxforge .build/EmaxForge.app/Contents/MacOS/EmaxForge

# Copy icon
cp EmaxForge/Resources/AppIcon.icns .build/EmaxForge.app/Contents/Resources/

# Copy reference templates (required for boot disk creation)
cp EmaxForge/Resources/emax2_header_*.bin .build/EmaxForge.app/Contents/Resources/ 2>/dev/null || true
cp EmaxForge/Resources/emax2_banktable_*.bin .build/EmaxForge.app/Contents/Resources/ 2>/dev/null || true
cp EmaxForge/Resources/emax2_boot_catalog.bin .build/EmaxForge.app/Contents/Resources/ 2>/dev/null || true
cp EmaxForge/Resources/emax2_os.bin .build/EmaxForge.app/Contents/Resources/ 2>/dev/null || true

# Copy Info.plist
cp EmaxForge/Resources/Info.plist .build/EmaxForge.app/Contents/

echo "✅ Build complete!"
echo "📦 App bundle: .build/EmaxForge.app"
echo ""
echo "To run: open .build/EmaxForge.app"
echo "To install: cp -r .build/EmaxForge.app /Applications/"
