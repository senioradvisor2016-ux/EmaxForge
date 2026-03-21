# UX Improvements — Emax Forge v0.3

**Created:** 2026-03-02  
**Current Status:** Phase 3 complete, production-ready beta  
**Goal:** Make Emax Forge the most user-friendly EMAX II tool

---

## 📊 CURRENT STATE ANALYSIS

### ✅ What Works Well
- Clean vintage synth aesthetic
- Large readable controls (80px knobs)
- Intuitive drag & drop
- Progress indicators on long operations
- Error dialogs with helpful messages
- Keyboard shortcuts (Space, Esc, Enter, Cmd+R)
- Visual feedback (waveforms, envelopes)

### ❌ What's Missing
- **No tooltips** on buttons/controls
- **No undo/redo** for destructive operations
- **No recent files** menu
- **No contextual help** (?-buttons)
- **No preferences** panel
- **Limited keyboard shortcuts**
- **No right-click menus**
- **No multi-select** for batch ops
- **No search/filter** in image list
- **No onboarding** for first-time users
- **No copy/paste** for samples/presets

---

## 🎯 PRIORITY 1: QUICK WINS (Low effort, high impact)

### 1. Tooltips Everywhere
**Impact:** 🟢🟢🟢 High  
**Effort:** 🟡 Low  
**Why:** Users don't have to guess what buttons do

**Implementation:**
```swift
Button("Export") { exportBank() }
    .help("Export this bank as .EB2 file")

Slider(value: $cutoff, in: 0...127)
    .help("Filter cutoff frequency (0-127)")
```

**Where to add:**
- All toolbar buttons
- All preset editor controls
- All waveform editor buttons
- Slot manager slots
- Config editor toggles

**Estimated time:** 2-3 hours (add ~50 tooltips)

---

### 2. Keyboard Shortcuts
**Impact:** 🟢🟢🟢 High  
**Effort:** 🟡 Low  
**Why:** Power users love keyboard navigation

**New shortcuts to add:**

| Shortcut | Action | Context |
|----------|--------|---------|
| **Cmd+O** | Open Volume | Global |
| **Cmd+R** | Refresh Images | Global |
| **Cmd+F** | Search/Filter | Image List |
| **Cmd+N** | New Image | Global |
| **Cmd+D** | Duplicate Image | Image selected |
| **Cmd+Backspace** | Delete Image | Image selected |
| **Cmd+I** | Show Image Info | Image selected |
| **Cmd+B** | Open Bank Browser | Image selected |
| **Cmd+Shift+B** | Backup & Restore | Volume selected |
| **Cmd+,** | Preferences | Global |
| **Space** | Play/Pause Sample | Sample preview |
| **←/→** | Previous/Next Sample | Bank browser |
| **Cmd+Z** | Undo | Editor |
| **Cmd+Shift+Z** | Redo | Editor |

**Implementation:**
```swift
.commands {
    CommandMenu("Images") {
        Button("New Image…") { showNewImage = true }
            .keyboardShortcut("n", modifiers: .command)
        
        Button("Duplicate Image…") { showDuplicate = true }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(selectedImage == nil)
    }
}
```

**Estimated time:** 3-4 hours

---

### 3. Status Bar
**Impact:** 🟢🟢 Medium  
**Effort:** 🟡 Low  
**Why:** Users always know what's happening

**What to show:**
- Selected image count (e.g., "3 of 12 images selected")
- Total volume space (e.g., "1.2 GB / 2 GB used")
- Current operation status (e.g., "Parsing banks…")
- Last action (e.g., "Renamed HD1.hda")

**Implementation:**
```swift
// At bottom of ContentView
HStack {
    if let msg = appState.statusMessage {
        Label(msg, systemImage: "info.circle")
    }
    Spacer()
    Text("\(appState.images.count) image(s)")
    if let volume = appState.selectedVolume {
        Text("•")
        Text(volume.formattedSpace)
    }
}
.font(.caption)
.padding(.horizontal)
.padding(.vertical, 4)
.background(.bar)
```

**Estimated time:** 1 hour

---

### 4. Empty States
**Impact:** 🟢🟢 Medium  
**Effort:** 🟡 Low  
**Why:** Guides new users what to do first

**Where:**
- No volumes mounted → "Connect a ZuluSCSI SD card"
- No images on volume → "Drag .hda files or create new image"
- No banks in image → "Import .EB2 banks from EMAX DRIVE"
- No samples in bank → "This bank contains no samples"

**Implementation:**
```swift
if appState.images.isEmpty {
    VStack(spacing: 16) {
        Image(systemName: "externaldrive.badge.questionmark")
            .font(.system(size: 60))
            .foregroundStyle(.tertiary)
        Text("No Images Found")
            .font(.title2.bold())
        Text("Drag .hda files here or create a new image")
            .foregroundStyle(.secondary)
        Button("Create New Image") { showNewImage = true }
            .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

**Estimated time:** 2 hours

---

### 5. Right-Click Context Menus
**Impact:** 🟢🟢🟢 High  
**Effort:** 🟡 Medium  
**Why:** Faster access to common actions

**Image List Context Menu:**
- Rename
- Duplicate
- Delete
- Show in Finder
- Get Info
- Open Bank Browser
- Export

**Bank Browser Context Menu:**
- Edit Preset
- Export Bank
- Delete Bank
- Copy Bank Name

**Implementation:**
```swift
List(appState.images) { image in
    ImageRow(image: image)
        .contextMenu {
            Button("Rename…") { renameImage(image) }
            Button("Duplicate…") { duplicateImage(image) }
            Divider()
            Button("Open Bank Browser") { openBankBrowser(image) }
            Button("Show in Finder") { revealInFinder(image) }
            Divider()
            Button("Delete", role: .destructive) { deleteImage(image) }
        }
}
```

**Estimated time:** 2 hours

---

## 🎯 PRIORITY 2: MAJOR FEATURES (Higher effort, high impact)

### 6. Undo/Redo System
**Impact:** 🟢🟢🟢 High  
**Effort:** 🔴 High  
**Why:** Safety net for destructive operations

**What to track:**
- Sample edits (crop, normalize, reverse)
- Preset changes
- Image renames
- Bank deletes
- File operations

**Implementation:**
Use `UndoManager` + `@Published` history:
```swift
class EditHistory: ObservableObject {
    private var undoManager = UndoManager()
    
    func recordEdit(_ action: EditAction) {
        undoManager.registerUndo(withTarget: self) { history in
            action.undo()
            history.recordEdit(action.inverse())
        }
    }
    
    func undo() {
        undoManager.undo()
    }
    
    func redo() {
        undoManager.redo()
    }
}
```

**Estimated time:** 8-10 hours

---

### 7. Preferences Panel
**Impact:** 🟢🟢 Medium  
**Effort:** 🟡 Medium  
**Why:** Personalization & workflow optimization

**Settings to add:**

**General:**
- Default volume path
- Auto-refresh interval
- Confirm destructive actions (toggle)
- Show welcome screen on launch

**Audio:**
- Default sample rate (42k / 44.1k)
- Bit depth (16-bit)
- Audio output device

**Editor:**
- Knob size (60px / 80px / 100px)
- Waveform color scheme
- Enable/disable animations

**Advanced:**
- Debug mode
- Log level
- ZuluSCSI config template

**Implementation:**
```swift
struct SettingsView: View {
    @AppStorage("defaultVolumePath") var defaultPath = ""
    @AppStorage("autoRefresh") var autoRefresh = true
    @AppStorage("confirmDeletes") var confirmDeletes = true
    
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gear") }
            AudioSettings()
                .tabItem { Label("Audio", systemImage: "waveform") }
            EditorSettings()
                .tabItem { Label("Editor", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 500, height: 400)
    }
}
```

**Estimated time:** 6-8 hours

---

### 8. Recent Files Menu
**Impact:** 🟢🟢 Medium  
**Effort:** 🟡 Low  
**Why:** Quick access to frequently used volumes

**Implementation:**
```swift
@AppStorage("recentVolumes") var recentVolumes: [String] = []

// In menu:
CommandMenu("File") {
    Button("Open Volume…") { openVolume() }
        .keyboardShortcut("o", modifiers: .command)
    
    Menu("Open Recent") {
        ForEach(recentVolumes, id: \.self) { path in
            Button(URL(fileURLWithPath: path).lastPathComponent) {
                openVolume(at: URL(fileURLWithPath: path))
            }
        }
        Divider()
        Button("Clear Recent") { recentVolumes.removeAll() }
    }
    .disabled(recentVolumes.isEmpty)
}
```

**Estimated time:** 2 hours

---

### 9. Search & Filter
**Impact:** 🟢🟢🟢 High  
**Effort:** 🟡 Medium  
**Why:** Essential for large collections

**Where:**
- Image list (filter by SCSI ID, name, size)
- Bank browser (filter banks by name)
- Sample list (filter samples by name, size)
- Knowledge base (already has search)

**Implementation:**
```swift
@State private var searchText = ""

var filteredImages: [DiskImage] {
    if searchText.isEmpty { return appState.images }
    return appState.images.filter {
        $0.filename.localizedCaseInsensitiveContains(searchText) ||
        $0.label?.localizedCaseInsensitiveContains(searchText) == true
    }
}

// In toolbar:
TextField("Search images…", text: $searchText)
    .textFieldStyle(.roundedBorder)
    .frame(width: 200)
```

**Estimated time:** 3 hours

---

### 10. Multi-Select Operations
**Impact:** 🟢🟢🟢 High  
**Effort:** 🔴 High  
**Why:** Batch operations on multiple images

**Actions:**
- Delete multiple images
- Batch rename with pattern
- Export multiple banks
- Move to folder

**Implementation:**
```swift
@State private var selectedImages: Set<DiskImage.ID> = []

List(appState.images, selection: $selectedImages) { image in
    ImageRow(image: image)
}
.listStyle(.plain)

// Toolbar shows batch actions when selection.count > 0
if !selectedImages.isEmpty {
    HStack {
        Text("\(selectedImages.count) selected")
        Button("Delete All") { deleteSelected() }
        Button("Batch Rename…") { batchRename() }
    }
}
```

**Estimated time:** 4-5 hours

---

## 🎯 PRIORITY 3: POLISH (Nice-to-have)

### 11. Animations & Transitions
**Impact:** 🟡 Low  
**Effort:** 🟡 Medium  
**Why:** Professional feel, visual feedback

**Where:**
- Waveform zoom (smooth scale)
- Knob rotation (spring animation)
- Progress bars (easing)
- List insertions/deletions
- Sheet presentations

**Implementation:**
```swift
.animation(.spring(response: 0.3), value: zoomLevel)
.transition(.scale.combined(with: .opacity))
```

**Estimated time:** 3-4 hours

---

### 12. Drag & Drop Enhancements
**Impact:** 🟢 Medium  
**Effort:** 🟡 Medium  
**Why:** More intuitive workflows

**New drag targets:**
- Drag images between volumes (copy)
- Drag banks to desktop (export)
- Drag samples to DAW (export WAV)
- Drag folder of .EB2 files (batch import)

**Implementation:**
```swift
.onDrop(of: [.fileURL], delegate: ImageDropDelegate())
```

**Estimated time:** 4 hours

---

### 13. Onboarding Tutorial
**Impact:** 🟢 Medium  
**Effort:** 🔴 High  
**Why:** Helps first-time users

**Flow:**
1. Welcome screen (already exists)
2. "Connect your ZuluSCSI" overlay
3. "This is an image" callout
4. "Try opening a bank" hint
5. "Edit a sample" walkthrough

**Implementation:**
Use `@AppStorage("hasCompletedOnboarding")` + overlay views

**Estimated time:** 8-10 hours

---

### 14. Advanced Export Options
**Impact:** 🟢 Medium  
**Effort:** 🟡 Medium  
**Why:** Flexible workflows

**Export formats:**
- Single bank → .EB2 ✅ (already exists)
- All banks → ZIP
- Sample → WAV/AIFF/MP3
- Preset → JSON (for sharing)
- Entire volume → Disk image

**Estimated time:** 4-5 hours

---

### 15. Sample Waveform Enhancements
**Impact:** 🟢 Medium  
**Effort:** 🟡 Medium  
**Why:** Better editing experience

**Features:**
- Zoom to selection
- Snap to zero crossing
- Loop markers
- Peak meter
- Spectral view (optional)

**Estimated time:** 6-8 hours

---

## 📊 SUMMARY

### Quick Wins (1-2 days)
1. ✅ **Tooltips** (2-3h) — Immediate clarity
2. ✅ **Keyboard shortcuts** (3-4h) — Power user love
3. ✅ **Status bar** (1h) — Always informed
4. ✅ **Empty states** (2h) — Guides beginners
5. ✅ **Context menus** (2h) — Faster workflows

**Total:** ~12 hours | **Impact:** 🟢🟢🟢 Very High

---

### Major Features (1 week)
6. **Undo/Redo** (8-10h) — Safety net
7. **Preferences** (6-8h) — Personalization
8. **Recent files** (2h) — Convenience
9. **Search/filter** (3h) — Discoverability
10. **Multi-select** (4-5h) — Batch power

**Total:** ~25 hours | **Impact:** 🟢🟢🟢 High

---

### Polish (Optional, 1-2 weeks)
11. **Animations** (3-4h)
12. **Drag & drop++** (4h)
13. **Onboarding** (8-10h)
14. **Export options** (4-5h)
15. **Waveform++** (6-8h)

**Total:** ~27 hours | **Impact:** 🟢🟢 Medium

---

## 🎯 RECOMMENDED ROADMAP

**Phase 4A: Quick Wins (Week 1)**
- Day 1-2: Tooltips + Keyboard shortcuts
- Day 3: Status bar + Empty states
- Day 4: Context menus
- Day 5: Testing & bug fixes

**Phase 4B: Major Features (Week 2-3)**
- Week 2: Undo/Redo + Preferences
- Week 3: Search/Filter + Multi-select + Recent files

**Phase 4C: Polish (Optional)**
- As time permits, prioritize based on user feedback

---

## 💡 USER FEEDBACK PRIORITIES

After beta testing, ask users:
1. What feature do you miss the most?
2. What action takes too many clicks?
3. What's confusing about the UI?
4. What keyboard shortcut would you love?

Use real feedback to re-prioritize this list.

---

**Created:** 2026-03-02  
**Status:** Roadmap draft  
**Next:** Pick Phase 4A and start implementation!
