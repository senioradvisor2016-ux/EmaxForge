# Accessibility Patches for EmaxForge

## Purpose
Add accessibility identifiers to critical UI elements for AppleScript testing.

## Benefits
- AppleScript can find buttons/fields reliably
- Tests are stable across UI changes
- Better VoiceOver support for accessibility users

## Patches Needed

### ContentView.swift

**Line ~306:** Create Bootable Disk button
```swift
// BEFORE:
Button(action: { showBootableWizard = true }) {
    Label("Create Bootable Disk", systemImage: "wand.and.stars")
}
.help("Create bootable HD image (⌘⇧B)")

// AFTER:
Button(action: { showBootableWizard = true }) {
    Label("Create Bootable Disk", systemImage: "wand.and.stars")
}
.help("Create bootable HD image (⌘⇧B)")
.accessibilityIdentifier("createBootableButton")
```

**Line ~310:** Create Floppy button
```swift
// BEFORE:
Button(action: { showCreateFloppy = true }) {
    Label("Create Floppy", systemImage: "opticaldiscdrive")
}
.help("Create floppy .HFE image (⌘⇧F)")

// AFTER:
Button(action: { showCreateFloppy = true }) {
    Label("Create Floppy", systemImage: "opticaldiscdrive")
}
.help("Create floppy .HFE image (⌘⇧F)")
.accessibilityIdentifier("createFloppyButton")
```

**Line ~316:** Format Disk Image button
```swift
.accessibilityIdentifier("formatDiskButton")
```

**Line ~321:** Format SD/USB button
```swift
.accessibilityIdentifier("formatVolumeButton")
```

**Line ~326:** Batch Rename button
```swift
.accessibilityIdentifier("batchRenameButton")
```

**Line ~331:** Multi-Image Slots button
```swift
.accessibilityIdentifier("slotManagerButton")
```

### ImageListView.swift

**Line ~75:** Format SD/USB button
```swift
.accessibilityIdentifier("formatSDButton")
```

**Line ~84:** Create Floppy button
```swift
.accessibilityIdentifier("createFloppyButton2")
```

**Line ~93:** Create HD button
```swift
.accessibilityIdentifier("createHDButton")
```

**Line ~109:** Search field
```swift
TextField("Search images... (⌘F)", text: $searchText)
    .textFieldStyle(.plain)
    .focused($searchFieldFocused)
    .accessibilityIdentifier("searchField")
```

**Line ~158:** Create HD1 button (warning banner)
```swift
Button("Create HD1…") {
    NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
}
.buttonStyle(.bordered)
.tint(.white)
.accessibilityIdentifier("createHD1Button")
```

### BootableDiskWizard.swift

**Line ~134:** Wizard title
```swift
.accessibilityIdentifier("bootDiskWizardTitle")
```

**Find disk size picker:**
```swift
.accessibilityIdentifier("diskSizePicker")
```

**Find "Choose Location" button:**
```swift
.accessibilityIdentifier("chooseLocationButton")
```

**Find "Create" button:**
```swift
.accessibilityIdentifier("createButton")
```

**Find "Cancel" button:**
```swift
.accessibilityIdentifier("cancelButton")
```

### NewImageSheet.swift

**Find disk size picker:**
```swift
.accessibilityIdentifier("newImageDiskSizePicker")
```

**Find SCSI ID field:**
```swift
.accessibilityIdentifier("scsiIDField")
```

**Find filename field:**
```swift
.accessibilityIdentifier("filenameField")
```

## AppleScript Usage

After patches, use identifiers in tests:

```applescript
-- Find button by accessibility identifier
tell application "System Events"
    tell process "EmaxForge"
        set btn to first button of window 1 whose value of attribute "AXIdentifier" is "createBootableButton"
        click btn
    end tell
end tell
```

## Implementation Status

- [ ] ContentView.swift patches
- [ ] ImageListView.swift patches
- [ ] BootableDiskWizard.swift patches
- [ ] NewImageSheet.swift patches
- [ ] Test with quick-dump.sh
- [ ] Verify AppleScript can find all identifiers
- [ ] Update test scripts to use identifiers

## Testing

After applying patches:

```bash
# 1. Build app
cd ~/clawd/EmaxForge
./build.sh

# 2. Run app
open .build/EmaxForge.app

# 3. Dump UI
cd tests
./quick-dump.sh

# 4. Verify identifiers appear in logs/ui-dump.txt
grep "AXIdentifier" logs/ui-dump.txt
```
