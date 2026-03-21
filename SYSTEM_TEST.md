# Emax Forge v0.3 — System Test Checklist

**Test Date:** 2026-03-02  
**Build:** Release v0.3  
**Tester:** _________

---

## 🎯 TEST OVERVIEW

This checklist covers all features across Phase 1, 2, and 3.  
Mark ✅ when test passes, ❌ when fails, ⚠️ for issues.

---

## PHASE 1: AUDIO FOUNDATION

### Sample Preview & Playback
- [ ] **T1.1** — Select a sample from bank → waveform displays
- [ ] **T1.2** — Click Play → audio plays correctly
- [ ] **T1.3** — Progress indicator moves during playback
- [ ] **T1.4** — Pause/Resume works
- [ ] **T1.5** — Waveform zooms correctly (pinch/scroll)
- [ ] **T1.6** — Playback stops when switching samples

**Notes:**
```


```

---

### Waveform Editor
- [ ] **T2.1** — Open "Edit Sample" sheet
- [ ] **T2.2** — Visual waveform displays with controls
- [ ] **T2.3** — Crop: Set start/end markers → waveform updates
- [ ] **T2.4** — Trim Silence: Auto-removes silent regions
- [ ] **T2.5** — Fade In: Creates smooth fade at start
- [ ] **T2.6** — Fade Out: Creates smooth fade at end
- [ ] **T2.7** — Normalize: Peaks reach max amplitude
- [ ] **T2.8** — Reverse: Waveform plays backwards
- [ ] **T2.9** — "Save As" exports edited sample correctly
- [ ] **T2.10** — Original sample unchanged after "Save As"

**Notes:**
```


```

---

### Sample Converter
- [ ] **T3.1** — Drag WAV file → converts to EB2
- [ ] **T3.2** — Drag AIFF file → converts to EB2
- [ ] **T3.3** — Drag MP3 file → converts to EB2
- [ ] **T3.4** — Drag FLAC file → converts to EB2
- [ ] **T3.5** — Multi-file drag converts all files
- [ ] **T3.6** — Converted files load correctly in bank browser
- [ ] **T3.7** — Sample rate conversion (44.1k → 42k) works
- [ ] **T3.8** — 16-bit conversion works correctly

**Notes:**
```


```

---

## PHASE 2: ADVANCED EDITING

### Preset Editor
- [ ] **T4.1** — Open preset editor from sample
- [ ] **T4.2** — VCA envelope controls (Attack, Decay, Sustain, Release) update
- [ ] **T4.3** — Filter envelope controls update
- [ ] **T4.4** — Cutoff slider changes filter frequency
- [ ] **T4.5** — Resonance slider affects filter Q
- [ ] **T4.6** — Pan slider positions sample in stereo field
- [ ] **T4.7** — Chorus toggle enables/disables effect
- [ ] **T4.8** — Visual envelope displays update in real-time
- [ ] **T4.9** — "Save Preset" button enabled
- [ ] **T4.10** — Vintage aesthetic matches design goals

**Notes:**
```


```

---

### Bank Browser
- [ ] **T5.1** — Bank list displays all .EB2 files
- [ ] **T5.2** — Click bank → sample list populates
- [ ] **T5.3** — Sample count correct for each bank
- [ ] **T5.4** — Delete bank → confirmation dialog appears
- [ ] **T5.5** — Delete confirmed → bank removed from list
- [ ] **T5.6** — Export bank → file saved to chosen location
- [ ] **T5.7** — Double-click sample → opens preset editor
- [ ] **T5.8** — Search/filter works (if implemented)

**Notes:**
```


```

---

### Sample Reordering
- [ ] **T6.1** — Drag sample to new position
- [ ] **T6.2** — Sample list updates immediately
- [ ] **T6.3** — Key zones auto-update after reorder
- [ ] **T6.4** — Keyboard display shows updated zones
- [ ] **T6.5** — Reorder persists after app restart (if saved)
- [ ] **T6.6** — Multiple samples can be reordered
- [ ] **T6.7** — Undo/Redo works (if implemented)

**Notes:**
```


```

---

## PHASE 3: POWER TOOLS

### Multi-Image Slot Manager
- [ ] **T7.1** — Open Slot Manager from toolbar
- [ ] **T7.2** — Visual grid displays HD1_0 through HD1_9
- [ ] **T7.3** — Drag image to slot → assigns correctly
- [ ] **T7.4** — Active slot highlighted
- [ ] **T7.5** — Rename slot (friendly name)
- [ ] **T7.6** — Remove slot assignment
- [ ] **T7.7** — "Apply Changes" updates zuluscsi.ini
- [ ] **T7.8** — Boot config updated if HD0 slot changed
- [ ] **T7.9** — Preview shows image details (size, type)
- [ ] **T7.10** — Slot assignments persist after restart

**Notes:**
```


```

---

### Backup & Restore
**Backup:**
- [ ] **T8.1** — Open "Backup & Restore" from toolbar
- [ ] **T8.2** — Backup tab shows file list
- [ ] **T8.3** — Total size calculated correctly
- [ ] **T8.4** — Click "Create Backup" → file dialog appears
- [ ] **T8.5** — Progress bar shows during backup
- [ ] **T8.6** — ZIP archive created successfully
- [ ] **T8.7** — Compression ratio displayed
- [ ] **T8.8** — "Show in Finder" opens correct location
- [ ] **T8.9** — backup-info.json included in archive

**Restore:**
- [ ] **T8.10** — Switch to Restore tab
- [ ] **T8.11** — "Choose Backup File" opens file picker
- [ ] **T8.12** — Selected archive displays info (date, file count, size)
- [ ] **T8.13** — Overwrite toggle works
- [ ] **T8.14** — Click "Restore" → progress shown
- [ ] **T8.15** — Files restored to correct location
- [ ] **T8.16** — Overwrite=OFF skips existing files
- [ ] **T8.17** — Overwrite=ON replaces existing files
- [ ] **T8.18** — Image list refreshes after restore
- [ ] **T8.19** — Success message shows file count

**Notes:**
```


```

---

### Bootable Disk Wizard
- [ ] **T9.1** — Open wizard from toolbar
- [ ] **T9.2** — HD0 requirement message displays
- [ ] **T9.3** — Select OS file (.EMX)
- [ ] **T9.4** — Enter disk name
- [ ] **T9.5** — Choose size (512MB / 1GB / 2GB)
- [ ] **T9.6** — "Create Disk" button enabled
- [ ] **T9.7** — Progress shown during creation
- [ ] **T9.8** — HD0.hda created with correct size
- [ ] **T9.9** — OS file copied correctly
- [ ] **T9.10** — Disk bootable on real EMAX II

**Notes:**
```


```

---

## CORE FEATURES

### Volume Browser
- [ ] **T10.1** — Sidebar shows available volumes
- [ ] **T10.2** — Select volume → images load
- [ ] **T10.3** — Image count badge correct
- [ ] **T10.4** — Volume icon displays (SD card, USB, etc.)
- [ ] **T10.5** — Refresh button reloads volume list
- [ ] **T10.6** — Eject volume works (if implemented)

**Notes:**
```


```

---

### Image List
- [ ] **T11.1** — All .hda/.EZ2 files displayed
- [ ] **T11.2** — File size shown correctly
- [ ] **T11.3** — SCSI ID parsed from filename
- [ ] **T11.4** — Icon matches device type
- [ ] **T11.5** — Selection highlights row
- [ ] **T11.6** — Double-click opens preview/editor
- [ ] **T11.7** — Right-click context menu works

**Notes:**
```


```

---

### Batch Rename
- [ ] **T12.1** — Open "Batch Rename" from toolbar
- [ ] **T12.2** — Pattern field shows preview
- [ ] **T12.3** — ID sequence works (HD{id}.hda)
- [ ] **T12.4** — Custom prefix works
- [ ] **T12.5** — "Apply" renames all selected files
- [ ] **T12.6** — File list updates immediately
- [ ] **T12.7** — Undo available (if implemented)

**Notes:**
```


```

---

### ZuluSCSI Config Editor
- [ ] **T13.1** — Open "ZuluSCSI Config" from toolbar
- [ ] **T13.2** — Existing zuluscsi.ini loaded (if present)
- [ ] **T13.3** — Toggle options (debug, termination, quirks)
- [ ] **T13.4** — SCSI device mapping editor
- [ ] **T13.5** — "Save Config" writes zuluscsi.ini
- [ ] **T13.6** — Config syntax correct
- [ ] **T13.7** — Comments preserved
- [ ] **T13.8** — Validation prevents invalid settings

**Notes:**
```


```

---

### Knowledge Base
- [ ] **T14.1** — Open "Knowledge Base" from toolbar
- [ ] **T14.2** — Boot Requirements section displays
- [ ] **T14.3** — File Formats section displays
- [ ] **T14.4** — SCSI Termination guide displays
- [ ] **T14.5** — Search works (if implemented)
- [ ] **T14.6** — Links/references correct
- [ ] **T14.7** — Copy code snippets work

**Notes:**
```


```

---

### Hex Preview
- [ ] **T15.1** — Open hex view for image
- [ ] **T15.2** — Hex dump displays correctly
- [ ] **T15.3** — ASCII column shows readable chars
- [ ] **T15.4** — Scroll through large files
- [ ] **T15.5** — Search/filter (if implemented)

**Notes:**
```


```

---

## GENERAL UI/UX

### Performance
- [ ] **P1** — App launches in <3 seconds
- [ ] **P2** — Volume scan completes in <2 seconds
- [ ] **P3** — No UI freezes during operations
- [ ] **P4** — Large files (>100MB) load smoothly
- [ ] **P5** — Memory usage reasonable (<500MB idle)

### Stability
- [ ] **S1** — No crashes during normal use
- [ ] **S2** — Error dialogs show helpful messages
- [ ] **S3** — Invalid files handled gracefully
- [ ] **S4** — Corrupt banks don't crash app
- [ ] **S5** — App recovers from background errors

### Aesthetics
- [ ] **A1** — Vintage synth visual style consistent
- [ ] **A2** — Soundtoys-inspired clean design
- [ ] **A3** — Controls large/readable (80px knobs, 13-14pt fonts)
- [ ] **A4** — Color scheme matches theme
- [ ] **A5** — Animations smooth (60fps)

### Keyboard/Shortcuts
- [ ] **K1** — Cmd+O opens volume
- [ ] **K2** — Cmd+R refreshes
- [ ] **K3** — Space plays/pauses sample
- [ ] **K4** — Delete removes selection
- [ ] **K5** — Esc closes sheets/dialogs

---

## CRITICAL PATH TEST

**Simulate real workflow:**
1. [ ] Mount USB drive with EMAX II content
2. [ ] Open volume in Emax Forge
3. [ ] Browse bank → select sample → preview
4. [ ] Edit sample (crop, normalize) → save
5. [ ] Reorder samples → update key zones
6. [ ] Edit preset (adjust envelope)
7. [ ] Create backup of entire volume
8. [ ] Unmount/remount drive
9. [ ] Restore backup to drive
10. [ ] Verify all files restored correctly

**Notes:**
```


```

---

## HARDWARE COMPATIBILITY

### ZuluSCSI Testing
- [ ] **H1** — Images created by Forge boot on ZuluSCSI
- [ ] **H2** — SCSI IDs recognized correctly
- [ ] **H3** — Config changes take effect
- [ ] **H4** — Multi-image slots work on hardware

### EMAX II Testing
- [ ] **H5** — Boot disk loads OS successfully
- [ ] **H6** — Banks load in EMAX II OS
- [ ] **H7** — Samples play correctly
- [ ] **H8** — Presets sound as expected
- [ ] **H9** — Edited samples match editor preview

**Notes:**
```


```

---

## KNOWN ISSUES

Document any bugs/limitations found:

1. 
2. 
3. 

---

## FINAL VERDICT

- **Total Tests:** ___ / ___
- **Pass Rate:** ___%
- **Critical Failures:** ___
- **Minor Issues:** ___
- **Ready for Release:** YES / NO

**Tester Signature:** ___________________  
**Date:** ___________________
