# standard tools Reverse Engineering Roadmap

## Vision: EmaxForge 2.0
**EmaxForge becomes the definitive Mac replacement for standard tools**
- All standard tools features (boot disks, bank editing, sample conversion)
- Multi-device support (EMAX I, II, ESI-32, Emulator III)
- Mac-native UX (SwiftUI, drag-drop, previews)
- Beyond standard tools (audio playback, waveform editing, preset editing)

## Phase 1: Tool Selection & Setup (Week 1)

### Primary Tool: Binary Ninja
**Why:** Best balance of power + Mac-native + reasonable price
```bash
# Download from https://binary.ninja
# Personal license: $149
# 30-day free trial available
```

### Secondary Tool: Cutter (Free)
**Why:** Good for quick analysis, already have radare2
```bash
brew install cutter
cutter ~/clawd/standard/standardn.exe
```

### Dynamic Analysis: Wine + API Monitor
**Why:** See exact API calls in real-time
```bash
brew install wine-stable
# Download API Monitor: https://www.rohitab.com/apimonitor
```

## Phase 2: Feature Discovery (Week 2)

### Map All Features
Run standard tools and document:
1. **Disk Operations**
   - Create boot disk ✅ (already understood)
   - Format disk
   - Verify disk
   - Clone disk

2. **Bank Operations**
   - Import .EB2
   - Export .EB2
   - Rename banks
   - Copy/paste banks
   - Delete banks

3. **Sample Operations**
   - Import WAV/AIFF
   - Export samples
   - Edit sample parameters
   - Trim/crop samples

4. **Device Support**
   - EMAX II (current)
   - EMAX I
   - ESI-32
   - Emulator III

### Documentation Method
For each feature:
```markdown
## Feature: Import WAV Sample
- Menu path: File → Import Sample
- Input: WAV file (16-bit, mono/stereo)
- Output: .EB2 bank with sample
- Algorithm: ?
- File format changes: ?
- standard tools validation: ?
```

## Phase 3: Algorithm Extraction (Week 3-4)

### Approach: Hybrid Analysis
1. **Static (Binary Ninja/Cutter):**
   - Find function responsible for feature
   - Decompile to C pseudocode
   - Document algorithm

2. **Dynamic (Wine + debugger):**
   - Run feature with test input
   - Log all file I/O
   - Capture exact byte sequences

3. **Validation:**
   - Implement in Swift
   - Test against standard tools output
   - Binary-compare results

### Priority Order
1. ✅ **Boot disk creation** (done!)
2. **Format disk** (blank disk structure)
3. **Import .EB2** (already in EmaxForge, verify compatibility)
4. **WAV → EB2 conversion** (critical for sample workflow)
5. **ESI-32 support** (expand device coverage)
6. **Preset editing** (voice parameter manipulation)

## Phase 4: Implementation (Ongoing)

### Development Process
For each feature:
1. **Research:** Decompile + dynamic analysis (1-2 days)
2. **Prototype:** Swift implementation (1-2 days)
3. **Test:** Compare with standard tools output (0.5 day)
4. **Integrate:** Add to EmaxForge UI (0.5-1 day)
5. **Document:** Update skill + README (0.5 day)

**Timeline:** ~5 days per feature × 10 features = 50 days = **7-10 weeks**

## Tools Summary

| Tool | Purpose | Cost | Platform |
|------|---------|------|----------|
| **Binary Ninja** | Primary decompiler | $149 | macOS native |
| **Cutter** | Quick analysis | Free | macOS native |
| **Wine + x64dbg** | Dynamic debugging | Free | Wine on macOS |
| **Hopper** | Alternative decompiler | €99 | macOS native |
| **IDA Free** | Heavyweight option | Free | Wine/native |

## Recommended Start

**Week 1:**
1. ✅ Install Cutter: `brew install cutter`
2. Open standard tools in Cutter, explore functions
3. Download Binary Ninja trial (30 days)
4. Compare Cutter vs Binary Ninja decompilation quality
5. Decide: Buy Binary Ninja or stick with Cutter

**Week 2:**
1. Set up Wine + x64dbg
2. Run standard tools's "Format Disk" feature under debugger
3. Log all WriteFile calls
4. Document disk format structure
5. Implement in Swift

**Week 3+:**
Repeat for each feature

## Success Metrics

**Short-term (1 month):**
- [ ] Boot disks verified on real EMAX II ✅
- [ ] Format disk feature matches standard tools
- [ ] WAV import creates compatible .EB2

**Mid-term (3 months):**
- [ ] All standard tools EMAX II features implemented
- [ ] ESI-32 support added
- [ ] EmaxForge distributed as standalone app

**Long-term (6 months):**
- [ ] EMAX I + Emulator III support
- [ ] Beyond standard tools: waveform editor, preset editor
- [ ] EmaxForge becomes THE tool for E-mu samplers

## Resources

**Documentation:**
- standard tools reverse engineering (already started): `~/clawd/EmaxForge/ghidra/`
- EMAX II HD format spec: `EMAX2_HD_FORMAT_SPEC.md`
- Edge case tests: `edge-case-tests/`

**Reference Disks:**
- Working standard tools boot: `~/clawd/BOOTY/Funkar/HD00.hda`
- EmaxForge boot: `~/clawd/BOOTY/Test bugfix/HD00.hda`
- standard tools templates (5 sizes): `~/clawd/EMPX_IMAGES_SIZES/*.EZ2`

**Community:**
- standard tools forums (if they exist)
- Vintage synth forums (ask about standard tools internals)
- E-mu user groups

---

**Next Action:** Hardware test boot disk TODAY, then decide on Binary Ninja vs Cutter for Phase 2
