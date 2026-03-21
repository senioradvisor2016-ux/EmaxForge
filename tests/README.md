# EmaxForge AppleScript Test Suite

🎯 **Token-efficient automated testing for EmaxForge**

## Overview

This test suite uses AppleScript + macOS Accessibility APIs to automate EmaxForge UI testing with minimal token cost (~200-500 tokens per test vs 5000+ for VNC/screenshots).

## Setup

### 1. Enable Accessibility for Terminal

```bash
# System Settings > Privacy & Security > Accessibility
# Add Terminal.app (needed for osascript)
```

Or via command line:
```bash
tccutil reset Accessibility com.apple.Terminal
# Then manually approve in System Settings
```

### 2. Apply Accessibility Patches

```bash
cd ~/clawd/EmaxForge/tests
./apply-accessibility.sh
```

This adds `.accessibilityIdentifier()` to critical SwiftUI elements.

### 3. Rebuild EmaxForge

```bash
cd ~/clawd/EmaxForge
./build.sh
```

### 4. Verify Setup

```bash
cd tests
./quick-dump.sh
cat logs/ui-dump.txt | grep AXIdentifier
```

You should see identifiers like `createBootableButton`, `searchField`, etc.

## Usage

### Run All Tests

```bash
cd ~/clawd/EmaxForge/tests
./run-tests.sh
```

Output:
```
╔════════════════════════════════════════╗
║   EmaxForge AppleScript Test Suite    ║
╔════════════════════════════════════════╗

Running: test-image-list
----------------------------------------
✅ PASS (3 seconds)

Running: test-boot-disk
----------------------------------------
✅ PASS (18 seconds)

╔════════════════════════════════════════╗
║           Test Summary                 ║
╚════════════════════════════════════════╝

Total Tests:  2
Passed:       2
Failed:       0

All tests passed! 🎉
```

### Quick UI Dump (Debugging)

```bash
./quick-dump.sh
```

Outputs current UI state to `logs/ui-dump.txt` (~200-300 tokens).

Use this to:
- Find button names/identifiers
- Verify UI structure
- Debug why tests fail

### Run Single Test

```bash
osascript applescript/test-boot-disk.applescript
```

### View Test Logs

```bash
# Latest test report
ls -t logs/test-report-*.txt | head -1 | xargs cat

# Detailed test results
cat logs/test-results.log

# UI dumps
cat logs/ui-dump.txt
```

## Available Tests

### `test-image-list.applescript`
- Launch app
- Verify toolbar buttons exist
- Test image list/selection
- Test search field
- ~3 seconds, ~200 tokens

### `test-boot-disk.applescript`
- Launch app
- Create boot disk via wizard
- Select 239 MB size
- Choose Desktop output
- Verify HD00.hda created
- Verify boot signature (0x78 0x82)
- Verify FAT structure
- ~18 seconds, ~400 tokens

## Writing New Tests

1. **Create test file:**
```bash
nano applescript/test-my-feature.applescript
```

2. **Use library functions:**
```applescript
set libPath to (path to home folder as text) & "clawd:EmaxForge:tests:applescript:lib.applescript"
set lib to load script file libPath

try
    lib's launchEmaxForge()
    lib's clickButton("My Button")
    lib's logResult("MyTest", "PASS", "Feature works")
    lib's quitEmaxForge()
    return "✅ PASS"
on error errMsg
    lib's logResult("MyTest", "FAIL", errMsg)
    return "❌ FAIL: " & errMsg
end try
```

3. **Run it:**
```bash
osascript applescript/test-my-feature.applescript
```

The test runner (`run-tests.sh`) automatically discovers `test-*.applescript` files.

## Library Functions

See `applescript/lib.applescript`:

- `launchEmaxForge()` - Launch and wait
- `clickButton(label)` - Click by text
- `clickButtonById(id)` - Click by accessibility ID
- `waitForSheet()` - Wait for modal dialog
- `selectPopupItem(label, item)` - Choose dropdown item
- `getTextFieldValue(index)` - Read text field
- `typeIntoField(index, text)` - Type into field
- `fileExists(path)` - Check file
- `verifyImageCreated(path)` - Verify .hda file
- `logResult(name, status, msg)` - Log to file
- `quitEmaxForge()` - Quit app

## Token Costs

| Method | Tokens per Run | Use Case |
|--------|----------------|----------|
| AppleScript test | ~200-500 | Regression testing |
| UI dump | ~200-300 | Quick debugging |
| XCTest output | ~100-300 | CI/CD automation |
| Screenshot | ~2000-3000 | Visual bugs only |
| VNC session | ~5000-15000 | Complex interactive debugging |

**Recommended workflow:**
1. Daily regression: `./run-tests.sh` (~500 tokens total)
2. Bug investigation: `./quick-dump.sh` (~200 tokens)
3. Visual verification: Screenshot only when needed (~2000 tokens)

## Integration with Claude

Claude can run tests autonomously:

```bash
# In heartbeat or on-demand:
cd ~/clawd/EmaxForge/tests && ./run-tests.sh

# Check results:
tail -20 logs/test-results.log

# Debug failures:
./quick-dump.sh
cat logs/ui-dump.txt
```

This enables **autonomous bug detection and regression testing** without human intervention.

## CI/CD Integration

Add to `.github/workflows/test.yml`:

```yaml
- name: Run UI Tests
  run: |
    cd ~/clawd/EmaxForge/tests
    ./run-tests.sh
```

Or local pre-commit hook:

```bash
#!/bin/bash
cd ~/clawd/EmaxForge
./build.sh && cd tests && ./run-tests.sh
```

## Troubleshooting

### "Process EmaxForge not found"
- EmaxForge is not running
- Wrong app name (check Activity Monitor)
- Solution: `launchEmaxForge()` auto-launches

### "Button not found"
- Accessibility identifier missing
- Button label changed
- Solution: Run `./quick-dump.sh` to see available buttons

### "Permission denied"
- Terminal lacks Accessibility permission
- Solution: System Settings > Privacy > Accessibility > Add Terminal

### Tests hang
- Dialog/alert blocking
- Sheet not dismissed
- Solution: Add `quitEmaxForge()` at end of test

### AppleScript syntax errors
- Use correct syntax (tell/end tell blocks)
- Escape special characters in strings
- Solution: Test snippets with `osascript -e '...'`

## Files

```
tests/
├── README.md                      # This file
├── ACCESSIBILITY_PATCHES.md       # Patch documentation
├── apply-accessibility.sh         # Auto-patch script
├── run-tests.sh                   # Test runner
├── quick-dump.sh                  # UI dump helper
├── applescript/
│   ├── lib.applescript                   # Reusable functions
│   ├── test-boot-disk.applescript        # Boot disk test
│   ├── test-image-list.applescript       # Image list test
│   └── dump-ui.applescript               # UI tree dumper
├── logs/
│   ├── test-report-*.txt          # Test reports
│   ├── test-results.log           # Detailed results
│   └── ui-dump.txt                # Latest UI dump
└── backups/
    └── YYYYMMDD_HHMMSS/           # Pre-patch backups
```

## Next Steps

1. ✅ Apply accessibility patches
2. ✅ Build EmaxForge
3. ✅ Run `./run-tests.sh`
4. ✅ Add tests for import banks, format disk, etc.
5. ✅ Integrate with CI/CD
6. ✅ Set up Claude heartbeat auto-testing

---

**Token-efficient. Autonomous. Regression-proof.** 🚀
