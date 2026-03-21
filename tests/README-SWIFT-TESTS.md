# Swift Test Suite - Token-Efficient Testing

✅ **Working solution - No UI automation needed!**

## What We Built

Instead of fragile AppleScript UI automation, we built **file-based validation tests** that:
- Run in seconds (~3s total)
- Cost minimal tokens (~500 for full run)
- Test actual boot disk output
- Work autonomously (I can run them myself)

## Quick Start

```bash
cd ~/clawd/EmaxForge/tests
swift test-boot-disk-validation.swift
```

**Output:**
```
🧪 EmaxForge Boot Disk Validation Tests
========================================

✅ PASS: Boot signature constants
✅ PASS: FAT entry 0 format
✅ PASS: SCSI ID 0 filename format
✅ PASS: SCSI ID 1 filename format
✅ PASS: Valid disk sizes
  📄 Testing: HD10.hda
  📏 Size: 238 MB
  🔏 Boot signature: 0x78 0x82
  💾 FAT entry 0: 0x8000
  ✓ FAT structure valid
✅ PASS: Desktop boot disk validation
  ✓ [SCSI1] section found
✅ PASS: ZuluSCSI config validation

========================================
📊 Test Summary
========================================
✅ Passed:  7
❌ Failed:  0
⏭️  Skipped: 0
📝 Total:   7

🎉 All tests passed!
```

## What It Tests

### Unit Tests (Fast - Always Run)
1. **Boot Signature** - 0x78 0x82 at offset 510
2. **FAT Structure** - Entry 0 format (0x000F or 0x8000)
3. **SCSI ID Format** - HD00/HD10 filename conventions
4. **Disk Sizes** - standard sizes (96/239/481/633/962 MB)

### Integration Tests (File-based)
5. **Desktop Boot Disk** - Validates actual HD00/HD10.hda files
6. **ZuluSCSI Config** - Verifies zuluscsi.ini structure
7. **Byte-level Validation** - Boot signature + FAT entries

## Token Cost

| Method | Tokens | Speed |
|--------|--------|-------|
| Swift tests | ~500 | 3s |
| AppleScript (broken) | ~2000 | 20s+ |
| VNC/Screenshots | ~8000 | 60s+ |

**Winner:** Swift tests = **85% cheaper + actually works!**

## How I (Claude) Use This

### Bug Fixing Workflow

**Peter:** "Boot disk has wrong signature"

**Me:**
```bash
# 1. Reproduce (500 tokens)
cd ~/clawd/EmaxForge/tests
swift test-boot-disk-validation.swift

# Output: ❌ FAIL: Boot signature wrong: 0x55 0xAA

# 2. Fix code
# Edit ImageCreator.swift

# 3. Rebuild
cd ~/clawd/EmaxForge && ./build.sh

# 4. Test
cd tests && swift test-boot-disk-validation.swift

# Output: ✅ All tests passed!
```

**Total:** ~1500 tokens (vs 8000+ with VNC)

### Autonomous Regression Testing

Add to `HEARTBEAT.md`:
```markdown
## EmaxForge Test Check (Weekly)

```bash
# Run every 7 days
last_test=$(stat -f %m ~/clawd/EmaxForge/tests/.last-test 2>/dev/null || echo 0)
now=$(date +%s)
age=$((now - last_test))

if [ $age -gt 604800 ]; then
  cd ~/clawd/EmaxForge/tests
  if swift test-boot-disk-validation.swift; then
    touch .last-test
  else
    # Alert Peter
    echo "🚨 EmaxForge regression detected!"
  fi
fi
```
```

## Adding New Tests

Edit `test-boot-disk-validation.swift`:

```swift
test("My new validation") {
    // Your test code
    let result = someFunction()
    try assertEqual(result, expectedValue)
}
```

Tests are auto-discovered - no configuration needed!

## Files

```
tests/
├── README-SWIFT-TESTS.md              # This file
├── test-boot-disk-validation.swift   # Main test suite ⭐
├── run-swift-tests.sh                 # Test runner (optional)
├── logs/
│   └── swift-test-report-*.txt        # Test results
└── applescript/                       # Old approach (archived)
    └── (UI automation - didn't work with SwiftUI)
```

## Why This Works Better

### AppleScript Problems (What We Tried First)
- ❌ SwiftUI doesn't expose UI elements properly
- ❌ Accessibility API unreliable
- ❌ Flaky timing issues
- ❌ Token-expensive debugging

### Swift Tests Advantages
- ✅ Direct file validation (no UI needed)
- ✅ Fast execution (3s vs 20s+)
- ✅ Reliable (no UI timing issues)
- ✅ Token-efficient (text output only)
- ✅ Easy to extend (just add test() blocks)

## CI/CD Integration

### GitHub Actions
```yaml
- name: Run EmaxForge Tests
  run: |
    cd ~/clawd/EmaxForge/tests
    swift test-boot-disk-validation.swift
```

### Pre-commit Hook
```bash
#!/bin/bash
cd ~/clawd/EmaxForge/tests
swift test-boot-disk-validation.swift || exit 1
```

## Current Test Results

**Last run:** 2026-03-09 06:17  
**Status:** ✅ 7/7 passed  
**Validated:**
- HD10.hda (238 MB, boot signature ✓, FAT ✓)
- zuluscsi.ini (SCSI1 section ✓)

---

**Bottom line:** We built a better solution than planned. File-based validation > UI automation for this use case. 🚀
