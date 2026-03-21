# Emax Forge v0.3 — Testing Guide

**Test Date:** 2026-03-02  
**Build:** Release v0.3  
**Status:** ✅ Code validation passed, ready for manual testing

---

## 🚀 QUICK START

### 1. Launch App
```bash
cd ~/clawd/EmaxForge
.build/release/EmaxForge &
```

The app is currently running (PID 41833, memory ~70MB).

### 2. Test Documents
- **`SYSTEM_TEST.md`** — Comprehensive test checklist (150+ test cases)
- **`CODE_VALIDATION.md`** — Code structure validation (automated)
- **This file** — Testing instructions

---

## 📋 TESTING STRATEGY

### Quick Smoke Test (15 min)
Test critical paths only:
1. Mount USB drive with EMAX II content
2. Open volume in app
3. Browse a bank → select sample → play
4. Edit a sample (normalize) → save
5. Create backup of volume
6. Restore backup

✅ If all pass → app is functional  
❌ If any fail → check error logs

---

### Full Regression Test (2-3 hours)
Use `SYSTEM_TEST.md` checklist:
- Phase 1 tests (T1.x - T3.x) — Audio foundation
- Phase 2 tests (T4.x - T6.x) — Advanced editing
- Phase 3 tests (T7.x - T9.x) — Power tools
- Core tests (T10.x - T15.x) — General features

Mark ✅/❌ for each test, document issues.

---

## 🧪 TEST SCENARIOS

### Scenario A: First-Time User
**Goal:** Validate onboarding experience

1. Launch app (fresh state)
2. Welcome screen should appear
3. Click "Open Volume"
4. Select mounted ZuluSCSI SD card
5. Volume should load with image list
6. Sidebar shows volume badge
7. Click an image → details display
8. No crashes, helpful messages

**Expected:** Smooth, intuitive flow

---

### Scenario B: Sample Workflow
**Goal:** Test Phase 1 features

1. Open bank browser
2. Select a bank with samples
3. Click a sample → preview plays
4. Waveform displays correctly
5. Pause/resume works
6. Open "Edit Sample"
7. Set crop markers → apply
8. Waveform updates in real-time
9. Click "Normalize" → audio peaks
10. "Save As" exports edited file
11. Verify new file loads correctly

**Expected:** All audio operations work smoothly

---

### Scenario C: Preset Editing
**Goal:** Test Phase 2 features

1. Open preset editor from sample
2. Adjust VCA Attack slider
3. Visual envelope updates
4. Adjust Filter Cutoff
5. Adjust Resonance
6. Toggle Chorus on/off
7. Pan slider left/right
8. All controls responsive
9. "Save Preset" button enabled
10. UI matches vintage aesthetic

**Expected:** Full parameter control, smooth UI

---

### Scenario D: Backup/Restore
**Goal:** Test Phase 3 critical feature

1. Open "Backup & Restore"
2. Backup tab shows file list
3. Total size calculated (e.g., 1.2 GB)
4. Click "Create Backup"
5. Choose save location
6. Progress bar animates 0-100%
7. ZIP file created (e.g., 800 MB)
8. Compression ratio ~33% shown
9. Switch to Restore tab
10. Select created backup
11. Archive info displays correctly
12. Enable "Overwrite existing"
13. Click "Restore"
14. Files restored, image list refreshes
15. Verify all images present

**Expected:** Reliable backup/restore cycle

---

### Scenario E: Slot Manager
**Goal:** Test Phase 3 multi-image feature

1. Open "Multi-Image Slots"
2. Visual grid displays HD1_0 - HD1_9
3. Drag an image to HD1_0
4. Slot shows image name/size
5. Rename slot to "Bass Patches"
6. Drag different image to HD1_1
7. Rename to "Lead Synths"
8. Set HD1_0 as active (highlight)
9. Click "Apply Changes"
10. Check zuluscsi.ini file
11. Verify entries for HD1_0, HD1_1
12. Boot config updated

**Expected:** Clean slot management, correct config

---

## 🐛 BUG REPORTING

### Template
```
**Test ID:** T4.2 (VCA envelope controls)
**Expected:** Attack slider updates envelope display
**Actual:** Slider moves but display freezes
**Steps to Reproduce:**
1. Open preset editor
2. Move Attack slider
3. Observe envelope display

**Environment:**
- macOS: 14.x
- Emax Forge: v0.3
- Build: Release

**Screenshot:** (if applicable)
```

### Log Collection
```bash
# Check console for errors
log show --predicate 'process == "EmaxForge"' --last 5m

# Copy crash logs
ls ~/Library/Logs/DiagnosticReports/EmaxForge*
```

---

## ✅ VALIDATION CHECKLIST

Before marking app as "production-ready":

- [ ] **All Phase 1 tests pass** (Audio foundation)
- [ ] **All Phase 2 tests pass** (Advanced editing)
- [ ] **All Phase 3 tests pass** (Power tools)
- [ ] **No critical bugs** (crashes, data loss)
- [ ] **Performance acceptable** (<3s launch, smooth UI)
- [ ] **UI matches design** (vintage synth aesthetic)
- [ ] **Hardware compatibility** (boots on real EMAX II)

---

## 🎯 NEXT STEPS

### After Testing
1. Fill out `SYSTEM_TEST.md` checklist
2. Document bugs in GitHub Issues (or equivalent)
3. Prioritize fixes (critical → nice-to-have)
4. Iterate on feedback

### Phase 4 Planning
1. **Unit Tests** — XCTest suite for core services
2. **CI/CD** — GitHub Actions for automated builds
3. **Code Signing** — Notarize for distribution
4. **OS Updater** — Auto-download latest EMAX II OS
5. **Cloud Library** — Community bank sharing

---

## 📞 SUPPORT

**Questions/Issues:**
- Check `CODE_VALIDATION.md` for technical details
- Check `MEMORY.md` for project history
- Consult `musicapp/SKILL.md` for JUCE patterns

**Hardware Testing:**
- ZuluSCSI: https://zuluscsi.com
- EMAX II manual: (your docs folder)

---

**Happy Testing! 🎹**
