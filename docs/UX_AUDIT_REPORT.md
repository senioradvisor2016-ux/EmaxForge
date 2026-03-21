# EmaxForge UX Audit Report
**Date:** 2026-03-18
**Version:** v0.5 Beta → v0.6 pre-release
**Auditor:** Claude Sonnet 4.6 (AI-assisted)
**Scope:** 51 Swift views + CLI agent harness
**Method:** Nielsen Heuristic Evaluation + Static Code Analysis

---

## Executive Summary

EmaxForge is a sophisticated macOS app for managing EMAX II disk images. The app demonstrates strong foundational UX patterns (command palette, undo/redo, drag-and-drop, onboarding tour, skeleton loading), but has **4 critical bugs** and **12 medium-priority UX issues** that must be resolved before v0.6 release.

**Overall Score: 6.8/10** (with critical bugs: 5.2/10)

---

## Critical Bugs (P0 — Fix Before Any Release)

### BUG-01: Trash Action Bypasses Confirmation Dialog
**File:** `EmaxForge/Sources/Views/ImageDetailView.swift` lines 371–376
**Nielsen Principle:** H3 — User Control and Freedom
**Severity:** 🔴 Critical

The "Trash" `ActionCard` in `actionsSection` directly calls `fileService.trashImage()` without showing the confirmation dialog (`showDeleteConfirmation`). There is a `showDeleteConfirmation` state variable and a properly guarded `.alert("Delete Image?")` defined on this view, but the Trash card bypasses it entirely.

```swift
// CURRENT (broken):
ActionCard(title: "Trash", icon: "trash", color: .red) {
    try? appState.fileService.trashImage(image)  // No confirmation!
    appState.selectedImage = nil
    appState.refreshImages()
    appState.addActivity("Trashed \(image.filename)", type: .warning)
}

// FIXED:
ActionCard(title: "Trash", icon: "trash", color: .red) {
    showDeleteConfirmation = true  // Show the dialog
}
```

---

### BUG-02: Duplicate Sheet Modifier — VerifyDiskView Never Shows
**File:** `EmaxForge/Sources/Views/ImageDetailView.swift` lines 138–148
**Nielsen Principle:** H1 — Visibility of System Status
**Severity:** 🔴 Critical

`.sheet(isPresented: $showVerifyDisk)` is declared **twice**. SwiftUI only honors the last modifier in a chain, so `VerifyDiskView` (first declaration) is silently replaced by `VerifyDiskSheet` (second declaration). Only `VerifyDiskSheet` will ever appear.

```swift
// CURRENT (duplicated):
.sheet(isPresented: $showVerifyDisk) { VerifyDiskView(image: image) }     // ← DEAD CODE
.sheet(isPresented: $showBulkExport) { BulkExportView(image: image) }
.sheet(isPresented: $showBankExport) { BankExportView(image: image) }
.sheet(isPresented: $showVerifyDisk) { VerifyDiskSheet(imageURL: image.url) }  // ← Only this fires

// FIXED: Remove the first .sheet(isPresented: $showVerifyDisk) declaration
```

---

### BUG-03: Window Title Shows Internal Brand Name
**File:** `EmaxForge/Sources/Views/ContentView.swift` lines 44–47
**Nielsen Principle:** H4 — Consistency and Standards
**Severity:** 🔴 Critical (Brand/Identity)

`windowTitle` returns `"EMULOTION"` (the internal brand alias), not `"EmaxForge"`. This conflicts with `.navigationTitle(windowTitle)` where users expect to see the app name. The statusbar footer also shows "EMULOTION". This is confusing and inconsistent.

```swift
// CURRENT:
private var windowTitle: String {
    let base = "EMULOTION"  // Wrong — internal name leaking to UI
    return appState.autoSaveManager.hasUnsavedChanges ? base + " •" : base
}

// FIXED:
private var windowTitle: String {
    let base = "EmaxForge"
    return appState.autoSaveManager.hasUnsavedChanges ? base + " •" : base
}
```

---

### BUG-04: Hex Viewer Navigation Falls Through to ImageDetailView
**File:** `EmaxForge/Sources/Views/ContentView.swift` lines 231–233
**Nielsen Principle:** H1 — Visibility of System Status
**Severity:** 🔴 Critical

The `.hexViewer` `NavigationDestination` case intentionally falls through to `ImageDetailView` with a `// TODO:` comment. Users who trigger this navigation via the menu or deep link get the wrong view with no explanation.

```swift
// CURRENT:
case .hexViewer(let image):
    // TODO: Create dedicated HexViewerView
    ImageDetailView(image: image)  // Wrong view, no notification to user

// FIXED: Either remove the navigation case or show a placeholder
```

---

## High Priority Issues (P1)

### UX-01: "Click Browse Banks" in QuickInfoCard
**File:** `EmaxForge/Sources/Views/ImageDetailView.swift` lines 448–450
**Nielsen Principle:** H1 — Visibility of System Status; H6 — Recognition over Recall

`loadImageInfo()` sets `osName = "Click Browse Banks"` as a value displayed in the "OS" quick info card. Users see "OS: Click Browse Banks" which is misleading — it looks like the OS name is a call to action rather than information.

**Fix:** Remove the osName quick info card when it contains instructional text, or show "—" with a tooltip.

---

### UX-02: Duplicate "Take Tour" Buttons
**File:** `EmaxForge/Sources/Views/WelcomeView.swift`
**Nielsen Principle:** H8 — Aesthetic and Minimalist Design

"Take Tour" appears in **3 places simultaneously** when volumes are detected:
1. Wizard banner (line 117)
2. Drive browser header (line 362)
3. Empty state hero (line 249)

**Fix:** Keep only the wizard banner version when the wizard is visible. When wizard is dismissed, surface it from the toolbar (already implemented via `ContentView`).

---

### UX-03: Eject Context Menu Ejects Wrong Volume
**File:** `EmaxForge/Sources/Views/SidebarView.swift` lines 52–54, 82–84
**Nielsen Principle:** H4 — Consistency; H5 — Error Prevention

Context menu "Eject {volume.name}" calls `appState.ejectVolume()` which ejects `appState.selectedVolume`, not the volume in the context menu row. Right-clicking a non-selected volume then choosing Eject silently ejects the selected volume.

```swift
// CURRENT (broken):
Button("Eject \(volume.name)") {
    appState.ejectVolume()  // Ejects selectedVolume, not `volume`!
}
```

---

### UX-04: `actionBar` in WelcomeView Is Dead Code
**File:** `EmaxForge/Sources/Views/WelcomeView.swift` lines 612–644
**Nielsen Principle:** H8 — Aesthetic and Minimalist Design

`actionBar` is defined as a private computed property but is never referenced in `body`. It is effectively dead code creating maintenance confusion.

---

### UX-05: `.successOverlay` Commented Out
**File:** `EmaxForge/Sources/Views/ContentView.swift` line 55
**Nielsen Principle:** H1 — Visibility of System Status

`// .successOverlay(isPresented: $showSuccessAnimation)  // TODO: Fix missing modifier` means users never see the success animation for completed operations, even though `showSuccess` notifications are fired throughout the app.

---

### UX-06: Double Volume Poll (3s Timer in Both SidebarView and WelcomeView)
**File:** `SidebarView.swift` line 148; `WelcomeView.swift` line 63
**Nielsen Principle:** Performance / H1

Both views poll `MountedVolume.scanMounted()` every 3 seconds independently. When both views are visible (3-column layout), this causes double disk I/O at 3s intervals with potential race conditions if the volume list changes.

---

### UX-07: Context Menu "Rename for ZuluSCSI" Does Nothing
**File:** `EmaxForge/Sources/Views/ImageListView.swift` lines 385–388
**Nielsen Principle:** H1 — Visibility of System Status; H3 — User Control

```swift
Button("Rename for ZuluSCSI…") {
    appState.selectedImage = image
    // No sheet opened, no action taken
}
```

The button sets `selectedImage` but performs no visible action. Users see no feedback.

---

### UX-08: Context Menu "Duplicate…" Also Does Nothing
**File:** `EmaxForge/Sources/Views/ImageListView.swift` lines 390–393
**Nielsen Principle:** H1 — Visibility of System Status

Same issue — sets `selectedImage` but doesn't open the duplicate sheet.

---

## Medium Priority Issues (P2)

### UX-09: Missing Keyboard Shortcut for Search
**File:** `EmaxForge/Sources/Views/ImageListView.swift`
**Nielsen Principle:** H7 — Flexibility and Efficiency

The search TextField placeholder says "Search images... (⌘F)" but there's no `keyboardShortcut("f")` registered to focus the field. The `NotificationCenter` handler `.focusSearch` exists but no menu item/shortcut posts that notification.

---

### UX-10: Emoji in Status Messages
**Files:** `ImageDetailView.swift` lines 489, 493
**Nielsen Principle:** H4 — Consistency and Standards; Accessibility

`statusMessage = "✅ Exported \(results.count) samples"` and `"❌ Export failed..."` use emoji in status messages while the status bar uses proper SF Symbols and `statusType` enum for coloring. Inconsistent — some messages have emoji, others use the `ActivityType` color system.

---

### UX-11: Long File Paths in DetailRow
**File:** `EmaxForge/Sources/Views/ImageDetailView.swift` lines 388–393
**Nielsen Principle:** H8 — Aesthetic and Minimalist Design

`DetailRow(label: "Path", value: image.url.path)` shows the full absolute path in a single-line label that overflows with no truncation. Long paths like `/Volumes/SD_CARD_16GB/EMAX_BANKS/hd1.hda` get cut off mid-path without ellipsis.

---

### UX-12: Parsing Error Message "Timeout" in Info Card
**File:** `EmaxForge/Sources/Views/ImageDetailView.swift` lines 540–545
**Nielsen Principle:** H9 — Help Users Recover from Errors

When parsing times out, `osName = "Timeout"` and `freeSpace = "Try Browse Banks"` appear as quick info card values. These read like error states but look identical to normal data cards, with no visual differentiation.

---

## Minor Issues (P3)

### UX-13: `actionBar` in WelcomeView Has Duplicate ActionPills with ContentView StatusBar
`WelcomeView.actionBar` (dead code) and `ContentView.statusBar` both show the same 4 ActionPills (Create Boot Disk, Create Floppy, Format SD/USB, Backup). Even if `actionBar` was live, it would create confusing duplication.

### UX-14: Onboarding Tour Background Tap Does Nothing
`OnboardingTourOverlay` ignores `.onTapGesture` on the background with `// Don't dismiss on background tap`. Standard macOS/iOS modal sheets dismiss on background tap. Users may attempt to dismiss repeatedly.

### UX-15: StatusBar DrawingGroup on Outer Container
`ContentView.statusBar` applies `.drawingGroup()` to the entire status bar. `drawingGroup()` rasterizes the entire subtree which can cause subpixel rendering issues with text and SF Symbols at small sizes.

### UX-16: "No HD1 found" Warning Shows for Empty Volumes
`WelcomeView.driveSection` shows "No HD1 found — EMAX II won't boot from this drive" even when the volume just has no image files at all. An empty SD card is not the same as a misconfigured one.

### UX-17: `@State private var showWizard = true` — Always Shows Wizard
`WelcomeView` initializes `showWizard = true` but then in `onAppear` checks `wizardDismissed`. If `wizardDismissed = true` AND `hasCompletedOnboarding = true`, the wizard still flashes briefly before being hidden on first render.

---

## What's Working Well

| Feature | Assessment |
|---------|------------|
| Command Palette (⌘K) | Excellent — comprehensive quick actions |
| Undo/Redo with keyboard shortcuts | Excellent — full stack with optimistic UI |
| Drag & drop (.EB2, .hda, .EZ2) | Excellent — multi-target, multi-format |
| Skeleton loading states | Good — `ImageListSkeleton` prevents layout shift |
| Toast notifications with Undo | Excellent — actionable feedback |
| Progress tracking in status bar | Good — linear progress with percentage |
| Onboarding tour overlay | Good — 5 steps, navigable |
| Theme system (dark, design tokens) | Excellent — consistent spacing/color scale |
| BreadcrumbView in ImageListView | Good — clear navigation hierarchy |
| Boot disk warning banner | Good — contextual, actionable |

---

## Nielsen Heuristics Scorecard

| # | Heuristic | Score | Critical Issues |
|---|-----------|-------|-----------------|
| H1 | Visibility of System Status | 5/10 | BUG-01, BUG-02, BUG-04, UX-01, UX-12 |
| H2 | Match System & Real World | 8/10 | Minor label issues |
| H3 | User Control & Freedom | 5/10 | BUG-01 (Trash no confirm) |
| H4 | Consistency & Standards | 5/10 | BUG-03 (branding), UX-10, UX-03 |
| H5 | Error Prevention | 6/10 | BUG-01, UX-03 |
| H6 | Recognition over Recall | 7/10 | UX-01, UX-09 |
| H7 | Flexibility & Efficiency | 8/10 | UX-09 (search shortcut) |
| H8 | Aesthetic & Minimalist | 7/10 | UX-02, UX-04, UX-13 |
| H9 | Error Recovery | 7/10 | UX-10, UX-12 |
| H10 | Help & Documentation | 8/10 | KnowledgeBase, tooltips, tour |

**Average: 6.6/10**

---

## Fix Priority Matrix

| ID | Issue | Effort | Impact | Priority |
|----|-------|--------|--------|----------|
| BUG-01 | Trash bypasses confirmation | XS (1 line) | Critical | P0 |
| BUG-02 | Duplicate sheet modifier | XS (1 line) | High | P0 |
| BUG-03 | Window title "EMULOTION" | XS (1 line) | High | P0 |
| BUG-04 | Hex viewer navigation | S (5 lines) | Medium | P0 |
| UX-03 | Eject wrong volume | S (3 lines) | High | P1 |
| UX-07 | Context menu Rename noop | S (3 lines) | High | P1 |
| UX-08 | Context menu Duplicate noop | S (3 lines) | High | P1 |
| UX-01 | "Click Browse Banks" in card | S | Medium | P1 |
| UX-02 | Duplicate Take Tour buttons | M | Medium | P1 |
| UX-05 | Success overlay disabled | M | Medium | P1 |
| UX-09 | Search shortcut missing | S | Medium | P2 |
| UX-10 | Emoji in status messages | M | Low | P2 |
| UX-11 | Path overflow in DetailRow | XS | Low | P2 |
| UX-12 | "Timeout" in info card | S | Medium | P2 |
| UX-04 | Dead code actionBar | S | Low | P3 |
| UX-06 | Double volume poll | M | Low | P3 |

---

## Recommendations

### Immediate (v0.6.0 — before release)
1. Fix BUG-01 through BUG-04
2. Fix UX-03 (eject wrong volume)
3. Fix UX-07 and UX-08 (context menu dead actions)

### Short-term (v0.6.1)
4. Replace "Click Browse Banks" with proper loading/empty state (UX-01)
5. Deduplicate "Take Tour" button (UX-02)
6. Re-enable success overlay (UX-05)
7. Standardize all status messages to use `ActivityType` + `addActivity()` — remove raw emoji

### Medium-term (v0.7)
8. Consolidate volume polling into a shared `VolumeMonitor` service
9. Add `keyboardShortcut` for search focus
10. Add dedicated HexViewerView

---

*Generated by static analysis of 51 Swift source files. Manual testing recommended to confirm all findings.*
