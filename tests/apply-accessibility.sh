#!/bin/bash
# Apply Accessibility Patches to EmaxForge
# Adds .accessibilityIdentifier() to critical UI elements

set -e

PROJECT_ROOT="$HOME/clawd/EmaxForge/EmaxForge"
SOURCES="$PROJECT_ROOT/Sources/Views"

echo "🔧 Applying accessibility patches to EmaxForge..."
echo ""

# Backup original files
echo "📦 Creating backups..."
timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="$HOME/clawd/EmaxForge/tests/backups/$timestamp"
mkdir -p "$backup_dir"

cp "$SOURCES/ContentView.swift" "$backup_dir/"
cp "$SOURCES/ImageListView.swift" "$backup_dir/"
cp "$SOURCES/BootableDiskWizard.swift" "$backup_dir/"
cp "$SOURCES/NewImageSheet.swift" "$backup_dir/"

echo "✅ Backups saved to: $backup_dir"
echo ""

# Patch ContentView.swift
echo "🔨 Patching ContentView.swift..."

# Create Bootable Disk button
perl -i -pe 's/(Label\("Create Bootable Disk", systemImage: "wand\.and\.stars"\))\s*}\s*(\.help\("Create bootable HD image \(⌘⇧B\)"\))/$1\n                }\n                $2\n                .accessibilityIdentifier("createBootableButton")/g' "$SOURCES/ContentView.swift"

# Create Floppy button
perl -i -pe 's/(Label\("Create Floppy", systemImage: "opticaldiscdrive"\))\s*}\s*(\.help\("Create floppy \.HFE image \(⌘⇧F\)"\))/$1\n                }\n                $2\n                .accessibilityIdentifier("createFloppyButton")/g' "$SOURCES/ContentView.swift"

echo "✅ ContentView.swift patched"

# Patch ImageListView.swift
echo "🔨 Patching ImageListView.swift..."

# Search field
perl -i -pe 's/(TextField\("Search images\.\.\. \(⌘F\)", text: \$searchText\))\s*(\.textFieldStyle\(\.plain\))/$1\n                        $2\n                        .accessibilityIdentifier("searchField")/g' "$SOURCES/ImageListView.swift"

# Create HD1 button (in warning banner)
perl -i -pe 's/(Button\("Create HD1…"\) \{)\s*/$1\n                        /g; s/(\.tint\(\.white\))/$1\n                    .accessibilityIdentifier("createHD1Button")/g' "$SOURCES/ImageListView.swift"

echo "✅ ImageListView.swift patched"

# Patch BootableDiskWizard.swift
echo "🔨 Patching BootableDiskWizard.swift..."

# Disk size picker (needs manual identification - will try common pattern)
sed -i '' 's/Picker("Disk Size", selection: $diskSize)/Picker("Disk Size", selection: $diskSize)\n                    .accessibilityIdentifier("diskSizePicker")/g' "$SOURCES/BootableDiskWizard.swift" 2>/dev/null || echo "⚠️  Disk size picker not found (check manually)"

echo "✅ BootableDiskWizard.swift patched"

# Patch NewImageSheet.swift
echo "🔨 Patching NewImageSheet.swift..."

# Similar approach for NewImageSheet
sed -i '' 's/TextField("File name", text: $filename)/TextField("File name", text: $filename)\n                        .accessibilityIdentifier("filenameField")/g' "$SOURCES/NewImageSheet.swift" 2>/dev/null || echo "⚠️  Filename field not found (check manually)"

echo "✅ NewImageSheet.swift patched"

echo ""
echo "🎉 Patches applied!"
echo ""
echo "Next steps:"
echo "  1. Rebuild: cd ~/clawd/EmaxForge && ./build.sh"
echo "  2. Test UI dump: cd tests && ./quick-dump.sh"
echo "  3. Run tests: ./run-tests.sh"
echo ""
echo "⚠️  MANUAL REVIEW NEEDED:"
echo "  Some patterns might not match perfectly."
echo "  Please review changes with:"
echo "    git diff $SOURCES/"
echo ""
echo "🔙 Restore backups if needed:"
echo "    cp $backup_dir/* $SOURCES/"
