# Manual Test Checklist — Emax Forge v0.3.1

**App Status:** Running (PID 43121)  
**Build:** Release  
**Date:** 2026-03-02

---

## 🧪 QUICK MANUAL TESTS (5 min)

### ✅ 1. STATUS BAR (30 sec)
**Where:** Bottom of main window

**Tests:**
- [ ] Launch app → Status bar visible at bottom?
- [ ] Shows "Ready" or similar message?
- [ ] Insert SD card → Image count appears? (e.g., "3 images")
- [ ] Volume space shown? (e.g., "1.2 GB / 2 GB")

---

### ✅ 2. EMPTY STATES (30 sec)
**Where:** Main content area

**Tests:**
- [ ] No volume selected → WelcomeView with "EMULOTION" logo?
- [ ] Empty volume → "No images found" + "Create New Image" button?
- [ ] Search with no matches → "No matches for..." message?

---

### ✅ 3. TOOLTIPS (1 min)
**Where:** Toolbar buttons

**Tests:**
- [ ] Hover over "Refresh" button → Tooltip appears?
- [ ] Tooltip shows "(⌘R)" shortcut hint?
- [ ] Hover over "Eject" → Shows "(⌘E)"?
- [ ] Hover over "Create Bootable Disk" → Shows "(⌘⇧B)"?
- [ ] All toolbar buttons have tooltips?

---

### ✅ 4. KEYBOARD SHORTCUTS (2 min)
**Where:** Entire app

**Priority shortcuts to test:**
```
Cmd+R         → Refresh images (instant response)
Cmd+O         → Open folder picker dialog
Cmd+E         → Eject volume (if volume selected)
Cmd+Shift+B   → Open Bootable Disk Wizard
Cmd+Shift+R   → Open Batch Rename sheet
Cmd+Shift+K   → Open Knowledge Base
```

**Image-specific (select an image first):**
```
Cmd+D         → Duplicate selected image
Cmd+Backspace → Delete selected image (trash)
Cmd+B         → Browse banks in image
```

**Menu shortcuts:**
- [ ] Check "Tools" menu exists (top menu bar)
- [ ] Tools > Batch Rename shows "⌘⇧R"?
- [ ] Tools > Multi-Image Slots shows "⌘⇧M"?
- [ ] File > Create Bootable Disk shows "⌘⇧B"?

---

### ✅ 5. CONTEXT MENUS (1 min)
**Where:** Image list, volumes

**Tests:**
- [ ] Right-click on image in list → Menu appears?
- [ ] Menu has: Browse Banks, Import Banks, Show in Finder, Duplicate, Delete?
- [ ] Right-click on volume in sidebar → Eject option?
- [ ] Right-click on bank (in Bank Browser) → Export/Delete?

---

## 🎯 ACCEPTANCE CRITERIA

**Pass if:**
- ✅ Status bar always visible with real-time updates
- ✅ All toolbar buttons have helpful tooltips
- ✅ At least 10 keyboard shortcuts work
- ✅ Empty states guide users clearly
- ✅ Context menus accessible on right-click

**Ship-blocker if:**
- ❌ Status bar missing or broken
- ❌ No tooltips on toolbar buttons
- ❌ Cmd+R (Refresh) doesn't work
- ❌ Empty state shows blank screen
- ❌ Context menus crash app

---

## 📸 VISUAL CHECKS

**Take screenshots of:**
1. Status bar (bottom) showing message + image count + space
2. WelcomeView (empty state)
3. Tooltip on hover (Refresh button)
4. Tools menu (top menu bar)
5. Context menu on right-click image

**Save to:** `EmaxForge/screenshots/v0.3.1/`

---

## 🐛 KNOWN ISSUES (if any)

*(None reported yet — update after testing)*

---

## 🚀 NEXT AFTER PASSING

1. Create `.app` bundle: `swift build -c release && tar -czf EmaxForge-v0.3.1.tar.gz .build/release/EmaxForge`
2. Test on fresh Mac (no dev tools)
3. Send to 2-3 beta testers
4. Collect feedback (1 week)
5. Plan Phase 4B (Undo/Redo, Preferences, etc.)

---

**Estimated testing time:** 5-10 minutes  
**Goal:** Ship v0.3.1 to beta if all ✅
