#!/bin/bash
set -e

echo "🤖 AUTONOMOUS BUILD STARTING..."

# Step 1: Build executable with SwiftPM
echo "1️⃣ Building executable..."
swift build --product EmaxForge -c release

# Step 2: Find the built executable
EXEC_PATH=$(swift build --show-bin-path -c release)/EmaxForge

if [ ! -f "$EXEC_PATH" ]; then
    echo "❌ Executable not found at: $EXEC_PATH"
    echo "Searching for build output..."
    find .build -name "EmaxForge" -type f 2>/dev/null
    exit 1
fi

echo "✅ Built: $EXEC_PATH"

# Step 3: Create .app bundle
echo "2️⃣ Creating app bundle..."
APP="EmaxForge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/"{MacOS,Resources}

cp "$EXEC_PATH" "$APP/Contents/MacOS/EmaxForge"
cp EmaxForge/Resources/*.icns "$APP/Contents/Resources/" 2>/dev/null || true

# Create Info.plist
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>EmaxForge</string>
    <key>CFBundleIdentifier</key>
    <string>com.emulotion.emaxforge</string>
    <key>CFBundleName</key>
    <string>EmaxForge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.6</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

echo "✅ Created: $APP"

# Step 4: Launch
echo "3️⃣ Launching..."
open "$APP"

echo "🎉 AUTONOMOUS BUILD COMPLETE!"
