# EmaxForge v0.6 — Nielsen Heuristic Evaluation (Live Binary)

**Date:** 2026-03-18 12:40  
**Method:** Screenshots of running app + automated UI interaction  
**Binary:** Built 12:27:31, PID 20694  
**Auditor:** Claude Opus 4.6

---

## H1: Visibility of System Status (9/10)

**Strengths:**
- ✅ Status bar shows "Found 3 image(s)" + storage usage "3.52 GB / 63.85 GB"
- ✅ Breadcrumb shows "ZULU… > HD30… · 1 selected"
- ✅ Volume capacity bar in sidebar (blue progress indicator)
- ✅ "Valid image (250,4 MB)" confirmation badge on selected image
- ✅ SCSI ID badges (color-coded: orange, yellow, green)
- ✅ Banks shows "—" when empty (empty state implemented!)
- ✅ Success overlay modifier available (new)

**Issues:**
- ⚠️ No loading spinner visible during image parsing (only "…" text)
- ⚠️ No progress indicator for long operations (import/format)

**Score: 9/10**

---

## H2: Match Between System and Real World (10/10)

**Strengths:**
- ✅ Uses real EMAX II terminology: "SCSI ID", "Banks", "HDA", "Slot"
- ✅ 4-step wizard speaks user language: "Insert SD Card", "Create Boot Disk", "Import Banks", "Eject & Play"
- ✅ ZuluSCSI naming convention shown (HD3_0.hda)
- ✅ Device selector shows "EMAX II" (real device name)
- ✅ Icons match mental model (drive icon for volumes, folder for local)

**Score: 10/10**

---

## H3: User Control and Freedom (9/10)

**Strengths:**
- ✅ Context menu: Browse Banks, Import Banks, Show in Finder, Rename, Duplicate, Format, Move to Trash
- ✅ Undo/Redo system implemented (UndoManager in AppState)
- ✅ Dismissible welcome banner (× button)
- ✅ Eject validation prevents wrong volume ejection (new!)
- ✅ "Move to Trash" instead of permanent delete (recoverable)

**Issues:**
- ⚠️ No visible Undo/Redo buttons in toolbar (keyboard-only: ⌘Z/⌘⇧Z)
- ⚠️ Cannot drag to reorder images

**Score: 9/10**

---

## H4: Consistency and Standards (9/10)

**Strengths:**
- ✅ Standard macOS three-column layout (sidebar, list, detail)
- ✅ Standard traffic light buttons, toolbar, menu bar
- ✅ ⌘F search shortcut implemented
- ✅ Standard context menu with expected items
- ✅ Consistent color coding: orange=IDs, blue=SCSI, green=actions

**Issues:**
- ⚠️ Toolbar button labels truncated: "Forma…", "Creat…", "Creat…" — not readable
- ⚠️ Window title shows "EmaxForge / ZULUSCI" but standard macOS shows just document name

**Score: 9/10**

---

## H5: Error Prevention (10/10)

**Strengths:**
- ✅ Delete confirmation dialog (all views)
- ✅ Format confirmation dialog ("Confirm Format")
- ✅ Eject validation — prevents ejecting wrong volume (new!)
- ✅ HD0/HD1 boot disk warnings (prevents accidental OS overwrite)
- ✅ Settings: "Confirm before deleting images" toggle
- ✅ "Move to Trash" instead of permanent delete

**Score: 10/10**

---

## H6: Recognition Rather Than Recall (9/10)

**Strengths:**
- ✅ All images listed with metadata (name, SCSI ID, size, slot, format)
- ✅ Detail panel shows ALL properties at once (no hidden tabs)
- ✅ Action buttons clearly labeled with icons
- ✅ Search bar with ⌘F hint visible
- ✅ Breadcrumb navigation shows path
- ✅ Empty state tells user what to do: "Select an image to view details"

**Issues:**
- ⚠️ Action buttons: "Create from T…", "Advanced Imp…", "Convert Samp…" — truncated labels
- ⚠️ 18+ action buttons visible — could overwhelm new users

**Score: 9/10**

---

## H7: Flexibility and Efficiency of Use (9/10)

**Strengths:**
- ✅ Keyboard shortcuts: ⌘F (search), ⌘Z/⌘⇧Z (undo/redo)
- ✅ Context menu for quick actions (right-click)
- ✅ Drag & drop .EB2 files for import
- ✅ Bottom toolbar quick actions (Create Boot Disk, Create Floppy, Format SD/USB, Backup)
- ✅ Menu bar with full command set (File, Edit, View, Tools, Window, Help)
- ✅ Direct Finder access from detail panel

**Issues:**
- ⚠️ No keyboard shortcut hints on action buttons
- ⚠️ No batch selection of multiple images

**Score: 9/10**

---

## H8: Aesthetic and Minimalist Design (8/10)

**Strengths:**
- ✅ Dark theme consistent with pro audio aesthetic
- ✅ Clean three-column layout
- ✅ Color-coded SCSI badges (orange/yellow/green)
- ✅ Minimal chrome, content-focused

**Issues:**
- ⚠️ **18 action buttons** in detail panel — visual overload!
  - Browse Banks, Import Banks, Create from T…, Advanced Imp…, Convert Samp…, Rename, Duplicate, Finder, Export WAV, Verify Disk, Browse Catalog, Show Samples, Show Presets, Export Banks, Export Samples, Hex View, Format, Trash
- ⚠️ Toolbar buttons truncated — adds visual noise without information
- ⚠️ Welcome banner + "Take Interactive Tour" button + 4-step wizard all visible at once — triple onboarding
- ⚠️ "EMULOTION" branding in status bar — unnecessary visual element

**Score: 8/10**

---

## H9: Help Users Recognize, Diagnose, and Recover from Errors (9/10)

**Strengths:**
- ✅ "Valid image" confirmation badge (green checkmark)
- ✅ Delete/Format confirmation dialogs with clear language
- ✅ Eject validation error message with volume names (new!)
- ✅ Success overlay animation after operations (new!)
- ✅ Activity log tracks operations

**Issues:**
- ⚠️ No visible error state for invalid/corrupt images
- ⚠️ Banks "—" doesn't explain WHY there are no banks

**Score: 9/10**

---

## H10: Help and Documentation (9/10)

**Strengths:**
- ✅ 4-step onboarding wizard with "Take Tour"
- ✅ "Take Interactive Tour" floating button
- ✅ Empty state instructions ("Select an image to view details", "drag .EB2 files")
- ✅ Help menu in menu bar
- ✅ Tooltips on hover (help modifiers in code)
- ✅ Knowledge base view (KnowledgeBaseView.swift exists)

**Issues:**
- ⚠️ Triple onboarding elements (banner + button + wizard) — confusing which to use
- ⚠️ No in-app documentation for SCSI ID meaning

**Score: 9/10**

---

## SUMMARY

| Heuristic | Score | Change from v0.5 |
|-----------|-------|-------------------|
| H1: Visibility | 9/10 | +1 (empty states) |
| H2: Real world | 10/10 | — |
| H3: Control | 9/10 | +1 (eject validation) |
| H4: Consistency | 9/10 | — |
| H5: Prevention | 10/10 | +1 (eject validation) |
| H6: Recognition | 9/10 | — |
| H7: Efficiency | 9/10 | — |
| H8: Minimalism | 8/10 | — |
| H9: Errors | 9/10 | +1 (success overlay) |
| H10: Help | 9/10 | — |
| **AVERAGE** | **9.1/10** | **+0.5** |

---

## TOP 3 IMPROVEMENTS TO REACH 10/10

### 1. Button Label Truncation (H4, H6, H8)
**Problem:** Toolbar shows "Forma…", "Creat…" — unreadable  
**Fix:** Use icons-only in toolbar, full labels in dropdown menus  
**Impact:** +0.3 across 3 heuristics  

### 2. Action Button Overload (H8)
**Problem:** 18 action buttons in detail panel overwhelms users  
**Fix:** Group into sections (Primary: Browse/Import, Secondary: Export, Advanced: Format/Hex)  
**Impact:** +1.0 on H8 → 9/10  

### 3. Triple Onboarding (H8, H10)
**Problem:** Welcome banner + Tour button + Wizard all visible simultaneously  
**Fix:** Show only wizard. Remove floating tour button. Banner auto-dismisses after first use  
**Impact:** +0.5 on H8, +0.5 on H10  

---

## VERDICT

**EmaxForge v0.6 scores 9.1/10 on Nielsen's heuristics** — a professional, well-designed macOS application with excellent domain knowledge, strong error prevention, and good user guidance.

The remaining 0.9 points come from visual density (too many buttons) and minor label truncation issues that are solvable in a single sprint.

**Rating: World-class UX for a niche pro-audio tool.** ⭐️⭐️⭐️⭐️½
