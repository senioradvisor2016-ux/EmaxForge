# EmaxForge - Next 7 Days Action Plan

## TODAY (Day 1): Hardware Verification
**Goal:** Test if EmaxForge boot disk actually boots on EMAX II

### Steps:
1. ✅ Copy `~/clawd/BOOTY/Test bugfix/` to ZuluSCSI SD card
2. ✅ Insert SD into EMAX II
3. ✅ Power on and observe boot sequence
4. **If boots:** 🎉 Mission accomplished! EmaxForge = production ready
5. **If fails:** Note error, move to dynamic analysis

**Time:** 30 minutes

---

## Day 2-3: Tool Setup & Comparison
**Goal:** Choose best reverse engineering tool for long-term work

### Install & Test Cutter (Free)
```bash
brew install --cask cutter  # Installing now...
cutter ~/clawd/standard/standardn.exe
```
- Explore standard tools functions
- Find "Create Boot Disk" function
- Decompile and read pseudocode
- Rate: 1-10 for readability

### Download Binary Ninja Trial (30 days)
https://binary.ninja/demo/
- Same process as Cutter
- Compare decompilation quality
- Rate: 1-10 for readability

### Decision Point
- If Cutter = 7+/10 → Use free tool
- If Binary Ninja = 9+/10 and Cutter = 5-/10 → Worth $149
- Document choice in `TOOLS_DECISION.md`

**Time:** 4-6 hours

---

## Day 4-5: Dynamic Analysis Setup
**Goal:** See standard tools in action, log all disk operations

### Wine + x64dbg
```bash
brew install wine-stable
cd ~/Downloads
# Download x64dbg from https://x64dbg.com
wine x64dbg.exe
```

### First Experiment: "Format Disk"
1. Run standard tools under x64dbg
2. Set breakpoint on `WriteFile`
3. Execute "Format Disk" → 239 MB
4. Log all writes (offset + data + size)
5. Compare with EmaxForge blank disk creation

### Output
→ `standard tools_FORMAT_DISK_LOG.txt` (complete write sequence)
→ Document any differences from EmaxForge

**Time:** 3-4 hours

---

## Day 6-7: Implement "Format Disk" Feature
**Goal:** Add compatible disk formatting to EmaxForge

### Implementation
1. Review standard tools log from Day 5
2. Update `ImageCreator.createBlankImage()` if needed
3. Add UI: "Tools → Format Disk"
4. Test against standard tools output (binary compare)

### Success Criteria
- EmaxForge formatted disk = standard tools formatted disk (hexdump match)
- Disk boots on real EMAX II (if applicable)

**Time:** 4-6 hours

---

## Week 2 Preview: WAV → EB2 Conversion
**Next big feature:**
- Reverse engineer standard tools's sample import
- Implement in EmaxForge
- Test with real EMAX II samples

---

## Tools Status

**Installing now:**
- ✅ Cutter (radare2 GUI)

**To install:**
- [ ] Binary Ninja trial (Day 2)
- [ ] Wine + x64dbg (Day 4)

**Already have:**
- ✅ Ghidra 12.0.4
- ✅ radare2 6.1.0
- ✅ EmaxForge v0.5 Beta (boot disk creation works!)

---

**First priority:** HARDWARE TEST! Allt annat är akademiskt om boot-disken inte fungerar.
