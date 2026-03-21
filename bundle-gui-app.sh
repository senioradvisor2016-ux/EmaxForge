#!/bin/bash
set -e

echo "🔨 Building EmaxForge GUI App..."

cd ~/clawd/EmaxForge/EmaxForge

# Build with SPM
echo "Building executable..."
swift build -c release 2>&1 | grep -E "Build complete|error:" || true

# Create proper .app bundle
echo "Creating .app bundle..."
APP_DIR="$HOME/Applications/EmaxForge.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/EmaxForge "$APP_DIR/Contents/MacOS/EmaxForge"
chmod +x "$APP_DIR/Contents/MacOS/EmaxForge"

# Copy resources
cp -r Resources/* "$APP_DIR/Contents/Resources/" 2>/dev/null || true

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>EmaxForge</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.emaxforge.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>EmaxForge</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.6</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 EmaxForge</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
</dict>
</plist>
EOF

echo "✅ App bundle created!"
echo "📦 Location: $APP_DIR"
echo ""
echo "Opening app..."
open "$APP_DIR"
