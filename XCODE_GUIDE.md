# EmaxForge + Xcode Development Guide

**Utveckla EmaxForge i Xcode med Claude Sonnet + Autonomous Loop**

---

## Snabbstart

```bash
# Öppna EmaxForge i Xcode
cd ~/clawd/EmaxForge
xed .
```

---

## Xcode Layout

### Projekt Struktur

```
EmaxForge/
├── Package.swift              # SPM manifest
├── EmaxForge/
│   ├── Sources/
│   │   ├── EmaxForgeApp.swift    # Main app
│   │   ├── Views/                # All SwiftUI views
│   │   ├── Models/               # Data models
│   │   ├── Services/             # Business logic
│   │   └── Extensions/           # Swift extensions
│   └── Resources/
│       ├── AppIcon.icns
│       ├── emax2_header_*.bin     # standard tools templates
│       └── emax2_os.bin          # OS binary
└── Tests/
    └── EmaxForgeTests/
```

### Xcode Schemes

**Scheme: EmaxForge**
- Build: Cmd+B
- Run: Cmd+R (launches app)
- Test: Cmd+U (runs test suite)
- Profile: Cmd+I (Instruments)

---

## Xcode 16 + Claude Sonnet Integration

### Enable Claude Assistant

1. **Xcode → Settings → AI Assistant**
2. Select **"Claude Sonnet"**
3. Sign in with Anthropic account
4. Done! ✅

### Using Claude in Xcode

**Real-Time Suggestions:**
- Type code → Claude suggests completions
- Press Tab to accept
- Press Esc to dismiss

**Quick Fix:**
- Click error/warning in code
- Claude suggests fix
- Click "Apply" to fix instantly

**Refactoring:**
- Select code
- Right-click → "Refactor with Claude"
- Choose refactoring (extract method, rename, etc.)

**Generate Tests:**
- Select function
- Right-click → "Generate Tests"
- Claude creates XCTest cases automatically

---

## Autonomous Loop Integration

### How It Works

**Workflow:**
```
Code in Xcode (with Claude suggestions)
    ↓
Save file (Cmd+S)
    ↓
Autonomous loop builds in background
    ↓
Errors detected? → Claude fixes automatically
    ↓
Loop reports success → Continue coding!
```

### Start Autonomous Loop

**Terminal 1 (Xcode):**
```bash
# Develop in Xcode as normal
xed ~/clawd/EmaxForge
```

**Terminal 2 (Autonomous Loop):**
```bash
# Start background monitoring
cd ~/clawd/xcode-autonomous
./test-emaxforge.sh
```

**What Happens:**
- Loop builds EmaxForge every iteration
- If errors found → Sends to Claude
- Claude fixes → Loop rebuilds
- Success → Telegram notification

---

## Development Workflows

### Workflow 1: Quick Fix (Xcode Claude)

**Use Case:** Single-file bug, quick iteration

```
1. Open file in Xcode
2. See error inline
3. Claude suggests fix
4. Apply with one click
5. Cmd+B to rebuild
6. Done! ✅
```

**Best For:**
- Syntax errors
- Type mismatches
- Simple logic bugs

### Workflow 2: Refactoring (Xcode Claude)

**Use Case:** Improve code structure

```
1. Select complex function
2. Right-click → Refactor with Claude
3. Choose: "Extract Method" / "Simplify" / "Add Tests"
4. Review suggestion
5. Accept
6. Cmd+B to verify
```

**Best For:**
- Large functions (>50 lines)
- Duplicate code
- Complex conditionals

### Workflow 3: Multi-File Changes (Autonomous Loop)

**Use Case:** Architecture changes, multiple files

```
1. Make changes across multiple files
2. Save all (Cmd+Opt+S)
3. Autonomous loop detects errors
4. Claude fixes all files automatically
5. Loop reports success
6. Review changes with git diff
```

**Best For:**
- Renaming classes/protocols
- API changes
- Dependency updates

### Workflow 4: New Feature (Hybrid)

**Use Case:** Build new feature from scratch

```
1. Create new file in Xcode
2. Type struct/class name
3. Claude generates boilerplate
4. Implement methods with Claude suggestions
5. Right-click → Generate Tests
6. Autonomous loop validates
7. All tests pass → Feature complete! ✅
```

---

## Common Tasks

### Build & Run

```bash
# In Xcode:
Cmd+B     # Build
Cmd+R     # Run app
Cmd+.     # Stop app

# Or via command line:
cd ~/clawd/EmaxForge
swift build                    # Build
swift run                      # Run
open .build/debug/EmaxForge    # Open built app
```

### Run Tests

```bash
# In Xcode:
Cmd+U     # Run all tests
Cmd+Opt+U # Run test at cursor

# Or via command line:
swift test                     # All tests
swift test --filter BootDisk   # Specific test
```

### Debug

```bash
# In Xcode:
Cmd+\     # Set breakpoint at line
Cmd+R     # Run with debugger
F6        # Step over
F7        # Step into
Cmd+K     # Clear console
```

### Code Navigation

```bash
Cmd+Shift+O   # Quick Open (search files/symbols)
Cmd+Shift+J   # Reveal in Project Navigator
Cmd+Opt+[     # Move line up
Cmd+Opt+]     # Move line down
Cmd+Opt+/     # Documentation comment
```

---

## Xcode + Claude Examples

### Example 1: Fix Cluster Offset Bug

**Error in Xcode:**
```swift
// ImageCreator.swift:165
let clusterOffset = clusterAreaStart + clusterSize  // ❌ Type error
```

**Claude Suggestion:**
```swift
// Fix: Add UInt64 cast
let clusterOffset = clusterAreaStart + UInt64(template.clusterSize)  // ✅
```

**Action:** Click "Apply Fix" → Cmd+B → Success!

### Example 2: Generate Tests

**Code in Xcode:**
```swift
func parseHDImage(at path: String) throws -> HDImage {
    // Complex parsing logic...
}
```

**Claude Action:**
- Right-click function → "Generate Tests"

**Generated:**
```swift
func testParseHDImageValid() throws {
    let path = "/path/to/test.hda"
    let image = try parseHDImage(at: path)
    XCTAssertNotNil(image)
    XCTAssertEqual(image.size, 250_398_720)
}

func testParseHDImageInvalid() {
    XCTAssertThrowsError(try parseHDImage(at: "/invalid"))
}
```

### Example 3: Refactor Complex View

**Before (ImageDetailView.swift):**
```swift
var body: some View {
    VStack {
        // 200 lines of view code...
    }
}
```

**Claude Refactor:**
```swift
var body: some View {
    VStack {
        headerSection
        statisticsSection
        actionsSection
    }
}

private var headerSection: some View { /* ... */ }
private var statisticsSection: some View { /* ... */ }
private var actionsSection: some View { /* ... */ }
```

**Result:** Better readability, easier testing!

---

## Troubleshooting

### Xcode Won't Build

**Check:**
```bash
# Clean build folder
Cmd+Shift+K in Xcode

# Or via command line:
swift package clean
rm -rf .build
```

### Xcode Claude Not Working

**Check:**
1. Xcode → Settings → AI Assistant
2. Is Claude Sonnet selected?
3. Are you signed in?
4. Try signing out and back in

### Autonomous Loop Not Detecting Changes

**Check:**
```bash
# Verify script is running
ps aux | grep xcode_watcher

# Check logs
tail -f ~/clawd/xcode-autonomous/logs/*.log
```

### Build Errors After Claude Fix

**Recovery:**
```bash
# Git reset if fix made things worse
git diff                # Review changes
git checkout -- .       # Revert all changes

# Or revert specific file:
git checkout -- EmaxForge/Sources/ImageCreator.swift
```

---

## Best Practices

### 1. Small Commits

```bash
# After each successful fix:
git add -A
git commit -m "Fix cluster offset calculation"
git push
```

### 2. Use Branches

```bash
# New feature branch
git checkout -b feature/bank-import

# Work in Xcode + autonomous loop

# When done:
git checkout main
git merge feature/bank-import
```

### 3. Review Before Accepting

- Always review Claude's suggestions
- Understand the fix before applying
- Run tests (Cmd+U) after big changes

### 4. Test Coverage

```bash
# Check test coverage in Xcode:
Product → Test (Cmd+U)
View → Navigators → Reports
Click latest test run
See coverage %
```

### 5. Combine Approaches

**Quick fixes:** Xcode Claude (instant)
**Refactoring:** Xcode Claude (supervised)
**Validation:** Autonomous loop (background)
**Testing:** Both (comprehensive)

---

## Keyboard Shortcuts Cheat Sheet

```
Build & Run:
Cmd+B           Build
Cmd+R           Run
Cmd+.           Stop
Cmd+Shift+K     Clean

Edit:
Cmd+/           Comment/uncomment
Cmd+[           Decrease indent
Cmd+]           Increase indent
Cmd+Opt+[       Move line up
Cmd+Opt+]       Move line down

Navigate:
Cmd+Shift+O     Quick Open
Cmd+Shift+J     Reveal in Navigator
Cmd+1-9         Show different navigators
Cmd+0           Toggle Navigator
Cmd+Opt+0       Toggle Inspectors

Debug:
Cmd+\           Toggle breakpoint
Cmd+Y           Toggle breakpoints
F6              Step over
F7              Step into
F8              Continue

Test:
Cmd+U           Run tests
Cmd+Opt+U       Run test at cursor
Cmd+Shift+U     Run last test

Claude:
Tab             Accept suggestion
Esc             Dismiss suggestion
Right-click     Claude menu
```

---

## Next Steps

1. **Now:** Build EmaxForge (Cmd+B)
2. **Try:** Change something → Let Claude suggest fix
3. **Enable:** Autonomous loop in background
4. **Monitor:** Success via Telegram
5. **Scale:** Add Dark Electrons, MusicApp

**Happy coding!** 🚀

---

## Resources

- **Xcode Docs:** Help → Xcode Help
- **Swift Docs:** Help → Developer Documentation
- **Claude Docs:** Xcode → Settings → AI Assistant → Help
- **Autonomous Loop:** `~/clawd/xcode-autonomous/README.md`
- **EmaxForge Tests:** `~/clawd/EmaxForge/Tests/`

---

**Questions? Problems? Ask Claude!** 💬
