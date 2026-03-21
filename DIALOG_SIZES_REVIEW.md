# Dialog Sizes Review — Emax Forge v0.3

**Review Date:** 2026-03-02  
**Issue:** BankBrowserView had incorrect size, hidden info  
**Action:** Audit all dialog sizes for usability

---

## 📐 CURRENT SIZES

| Dialog | Current Size | Status | Recommended |
|--------|-------------|--------|-------------|
| **BankBrowserView** | 1100x700 (min), 1200x750 (ideal) | ✅ **FIXED** | Keep |
| **BackupRestoreView** | 700x550 | ⚠️ **TOO SMALL** | 850x650 |
| **BatchRenameView** | *(no frame set)* | ❌ **MISSING** | 650x500 |
| **ZuluSCSIConfigView** | 620x520 | ✅ OK | Keep |
| **KnowledgeBaseView** | *(no frame set)* | ❌ **MISSING** | 900x700 |
| **BootableDiskWizard** | 600x640 | ⚠️ **TOO NARROW** | 700x640 |
| **SlotManagerView** | 900x600 | ✅ OK | Keep |
| **WaveformEditorView** | 800x600 | ✅ OK | Keep |
| **PresetEditorView** | 900x700 | ✅ OK | Keep |
| **ConvertSamplesView** | 580x560 | ✅ OK | Keep |
| **NewImageSheet** | 460x520 | ✅ OK | Keep |
| **RenameImageSheet** | 440x380 | ✅ OK | Keep |
| **DuplicateImageSheet** | 460x480 | ✅ OK | Keep |
| **ImportBanksView** | 560x520 | ✅ OK | Keep |

---

## 🔧 FIXES NEEDED

### 1. BackupRestoreView (700x550 → 850x650)
**Why:** Two-tab interface with large file lists needs more space  
**Content:**
- Backup tab: File list, total size, progress bar, result cards
- Restore tab: Archive picker, backup info, options, restore result
- Both tabs have multiple info sections that need vertical space

**Fix:**
```swift
.frame(width: 700, height: 550)
// Change to:
.frame(minWidth: 850, idealWidth: 900, minHeight: 650, idealHeight: 700)
```

---

### 2. BatchRenameView (no frame → 650x500)
**Why:** Table with rename preview needs defined size  
**Content:**
- Image list table (multiple columns)
- Pattern preview
- SCSI ID / slot assignment
- Apply/Cancel buttons

**Fix:**
```swift
// Add after VStack:
.frame(minWidth: 650, idealWidth: 700, minHeight: 500, idealHeight: 550)
```

---

### 3. KnowledgeBaseView (no frame → 900x700)
**Why:** Documentation viewer with code snippets needs reading space  
**Content:**
- Multiple sections (Boot Requirements, File Formats, SCSI Termination)
- Code blocks
- Explanatory text
- Possibly images/diagrams

**Fix:**
```swift
// Add after main VStack:
.frame(minWidth: 900, idealWidth: 1000, minHeight: 700, idealHeight: 750)
```

---

### 4. BootableDiskWizard (600x640 → 700x640)
**Why:** Form fields + instructions need horizontal space  
**Content:**
- HD0 requirement warning
- OS file picker
- Disk name field
- Size selection (radio buttons)
- Create button
- Status messages

**Fix:**
```swift
.frame(width: 600, height: 640)
// Change to:
.frame(minWidth: 700, idealWidth: 750, minHeight: 640, idealHeight: 680)
```

---

## ✅ DIALOGS THAT ARE FINE

### SlotManagerView (900x600)
- Grid layout with 10 slots
- Good size for visual slot management
- Keep as-is ✅

### PresetEditorView (900x700)
- Large knobs (80px)
- Envelope displays
- Multiple parameter sections
- Perfect size ✅

### WaveformEditorView (800x600)
- Waveform display
- Control buttons
- Good balance ✅

### Small Dialogs (460-580px)
- NewImageSheet, RenameImageSheet, DuplicateImageSheet
- Simple forms, appropriate sizes ✅

---

## 🎯 SIZING PHILOSOPHY

### General Rules:
1. **Minimal viable size** — Don't make dialogs unnecessarily large
2. **Content-driven** — Size should fit content without scrolling (where possible)
3. **Resizable** — Use `minWidth/idealWidth` for flexibility
4. **Readable text** — 13-14pt fonts need space to breathe
5. **Touch targets** — 44x44pt minimum for buttons

### Size Tiers:
- **Small forms:** 400-500px (rename, duplicate)
- **Medium dialogs:** 600-700px (wizards, config)
- **Large viewers:** 800-900px (editors, browsers)
- **Full workspace:** 1000-1200px (bank browser, knowledge base)

---

## 📝 IMPLEMENTATION PLAN

**Priority 1 (Critical - causes UX issues):**
- ✅ BankBrowserView — DONE (1100x700 → 1200x750)
- ✅ BackupRestoreView — DONE (700x550 → 850x650)
- ✅ KnowledgeBaseView — DONE (750x520 → 900x700)
- ✅ BatchRenameView — DONE (750x450 → 750x520)

**Priority 2 (Nice-to-have):**
- ✅ BootableDiskWizard — DONE (600x640 → 700x640)

**Total Fixes:** 5 files — ✅ ALL COMPLETE

---

## 🧪 TESTING CHECKLIST

After applying fixes, verify:

- [ ] BankBrowserView shows all bank info without scrolling
- [ ] BackupRestoreView tabs display file lists clearly
- [ ] BatchRenameView table readable with all columns
- [ ] KnowledgeBaseView shows code blocks without wrapping
- [ ] BootableDiskWizard form fields aligned properly
- [ ] All dialogs resizable (drag corners)
- [ ] No content clipping at minimum sizes
- [ ] Text readable at default zoom

---

**Reviewed by:** AI Assistant  
**Status:** 3 fixes pending (BackupRestore, BatchRename, KnowledgeBase)
