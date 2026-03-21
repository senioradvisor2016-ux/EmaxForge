# Claude Integration Guide

## How I (Claude) Use the Test Suite

This guide shows how I autonomously test EmaxForge bugs without asking Peter.

## My Workflow

### 1. Bug Report Arrives

Peter says: "Boot disk wizard creates HD0 instead of HD00"

### 2. I Reproduce It

```bash
# Run the specific test
cd ~/clawd/EmaxForge/tests
osascript applescript/test-boot-disk.applescript
```

**Output (text only, ~300 tokens):**
```
❌ FAIL: File not found at ~/Desktop/HD00.hda
(Found HD0.hda instead)
```

### 3. I Investigate

```bash
# Dump UI to see wizard state
./quick-dump.sh
cat logs/ui-dump.txt | grep -i "filename\|scsi"
```

**Output (~200 tokens):**
```
text field: "HD0.hda"
text field: "SCSI ID: 0"
```

### 4. I Find the Bug

```bash
# Read the relevant code
cat ~/clawd/EmaxForge/EmaxForge/Sources/Views/BootableDiskWizard.swift | grep -A5 "filename"
```

Found it: Line 245 uses single-digit SCSI ID.

### 5. I Fix It

```bash
# Edit the file
# Change: "HD\(scsiID).hda"
# To: "HD\(String(format: "%02d", scsiID)).hda"
```

### 6. I Verify the Fix

```bash
# Rebuild
cd ~/clawd/EmaxForge
./build.sh

# Re-test
cd tests
osascript applescript/test-boot-disk.applescript
```

**Output:**
```
✅ PASS: Boot disk created successfully
File: ~/Desktop/HD00.hda
Size: 250,609,664 bytes
Boot signature: 0x78 0x82 verified
```

### 7. I Run Full Regression

```bash
./run-tests.sh
```

**Output:**
```
Total Tests:  2
Passed:       2
Failed:       0

All tests passed! 🎉
```

### 8. I Report Back

"Fixed! HD00 naming now correct. All tests pass. Committed to repo."

## Total Token Cost

| Step | Method | Tokens |
|------|--------|--------|
| Reproduce | AppleScript test | 300 |
| Investigate | UI dump | 200 |
| Fix | Code edit | 0 |
| Verify | AppleScript test | 300 |
| Regression | Full test suite | 500 |
| **TOTAL** | | **~1300 tokens** |

**Compare to VNC approach:** ~8000 tokens for same debugging!

## Autonomous Bug Loop (No Human Needed)

### Scenario: Heartbeat finds regression

```bash
# In HEARTBEAT.md:
# Every 6 hours, run EmaxForge tests
cd ~/clawd/EmaxForge/tests && ./run-tests.sh
```

**If test fails:**
1. I capture failure log
2. I run `quick-dump.sh` for context
3. I analyze code
4. I attempt fix
5. I re-test
6. **Only then** I notify Peter with summary

Peter wakes up to: "Found and fixed boot disk regression. Tests green."

## Commands I Use

### Quick Health Check
```bash
cd ~/clawd/EmaxForge/tests
./run-tests.sh | tail -10
```

Returns just summary (~50 tokens).

### Specific Test
```bash
osascript applescript/test-boot-disk.applescript
```

### UI State Inspection
```bash
./quick-dump.sh
grep "button\|field\|picker" logs/ui-dump.txt
```

### Verify File Output
```bash
ls -lh ~/Desktop/HD*.hda
xxd -l 512 ~/Desktop/HD00.hda | head -20
```

### Code Search
```bash
cd ~/clawd/EmaxForge
grep -r "function_name" EmaxForge/Sources/
```

## When I Need Human Help

### ✅ I can handle autonomously:
- Button not clickable → check accessibility dump
- Wrong output filename → code fix + test
- Missing UI element → patch accessibility identifiers
- Test flakiness → add delays, improve selectors

### ⚠️ I need Peter for:
- Visual regressions (colors, layout) → screenshot needed
- Hardware-specific bugs → EMAX II testing
- UX/design decisions → "Should this be a sheet or window?"
- External dependencies → "Xcode version mismatch"

## Integration with Heartbeat

Add to `~/clawd/HEARTBEAT.md`:

```markdown
## EmaxForge Test Check (Daily)

```bash
# Run every 24h (avoid token burn)
last_test=$(stat -f %m ~/clawd/EmaxForge/tests/logs/test-results.log 2>/dev/null || echo 0)
now=$(date +%s)
age=$((now - last_test))

if [ $age -gt 86400 ]; then
  cd ~/clawd/EmaxForge/tests && ./run-tests.sh
  
  # Check results
  if grep -q "FAIL" logs/test-results.log; then
    # Alert Peter
    echo "🚨 EmaxForge regression detected!"
  fi
fi
```
```

## Best Practices

### DO:
- ✅ Run tests before reporting bugs fixed
- ✅ Use `quick-dump.sh` for quick debugging
- ✅ Check test logs for patterns
- ✅ Add new tests for new bugs (regression prevention)
- ✅ Keep test suite small (avoid token burn)

### DON'T:
- ❌ Run full test suite every heartbeat (too expensive)
- ❌ Use screenshots unless text fails (token waste)
- ❌ Make assumptions without testing
- ❌ Skip regression testing after fixes

## Example Bug Fix Session

**Peter:** "Create Bootable Disk wizard crashes when selecting 962 MB"

**Me:**
```bash
# 1. Reproduce
cd ~/clawd/EmaxForge/tests
osascript applescript/test-boot-disk.applescript

# Output: ❌ FAIL: App crashed after clicking Create

# 2. Check UI state before crash
./quick-dump.sh
# Shows: diskSize = "962 MB" selected

# 3. Check logs
Console.app or:
log show --predicate 'process == "EmaxForge"' --last 5m

# 4. Find crash reason
# Likely: ImageCreator.swift has no template for 962 MB

# 5. Read code
cat EmaxForge/Sources/Utilities/ImageCreator.swift | grep -A20 "962"
# Found: Missing case in switch statement

# 6. Fix
# Add 962 MB template to ImageCreator

# 7. Test
./build.sh && cd tests && osascript applescript/test-boot-disk.applescript
# ✅ PASS

# 8. Report
```

**Report to Peter:**  
"Fixed! 962 MB disk size was missing from ImageCreator templates. Added template with correct cluster size. Test now passes. 18s build + 20s test = 38s total fix time. 800 tokens."

## Continuous Improvement

As I fix bugs, I:

1. **Add tests for new scenarios**
   ```bash
   nano applescript/test-962mb-disk.applescript
   ```

2. **Improve library functions**
   ```applescript
   -- Add helper for multi-size testing
   on testDiskSize(sizeLabel)
       ...
   end testDiskSize
   ```

3. **Document patterns**
   ```markdown
   ## Common Bug Patterns
   - Missing template → Add to ImageCreator.swift
   - Wrong filename → Check formatter
   - Crash on create → Verify FAT/cluster logic
   ```

4. **Update MEMORY.md**
   ```markdown
   ## EmaxForge Learnings
   - 962 MB disk needs 96KB cluster size
   - Boot signature must be 0x78 0x82
   - SCSI ID must be zero-padded (HD00, not HD0)
   ```

---

**Result:** Faster debugging, fewer tokens, better test coverage, less human intervention. 🚀
