# EmaxForge CLI-Anything Harness

CLI wrapper for EmaxForge SwiftUI app to enable automated testing, development loops, and standard tools feature parity.

## Quick Start

```bash
# Install harness
cd ~/clawd/EmaxForge/agent-harness
pip install -e .

# Verify installation
cli-anything-emaxforge --version

# See available commands
cli-anything-emaxforge --help

# Try REPL mode
cli-anything-emaxforge repl
```

## Architecture

```
EmaxForge/
├── EmaxForge/              # SwiftUI app (Swift Package Manager)
├── agent-harness/          # CLI-Anything harness (Python)
│   ├── cli_anything/
│   │   └── emaxforge/
│   │       ├── emaxforge_cli.py  # Click CLI (main entry point)
│   │       ├── core/              # Business logic
│   │       ├── utils/             # Backend wrappers
│   │       │   └── swift_backend.py  # Wrap Swift CLIs
│   │       └── tests/             # Test suite
│   └── setup.py
├── cli-*.swift             # Existing Swift CLI scripts
└── build.sh                # Build EmaxForge.app
```

## Commands

### Disk Operations

```bash
# Create disk image
cli-anything-emaxforge disk create --size 239 --boot --output HD00.hda

# Format disk
cli-anything-emaxforge disk format --input HD10.hda --quick

# Show disk info
cli-anything-emaxforge disk info --input HD00.hda
```

### Bank Operations

```bash
# Import .EB2 bank
cli-anything-emaxforge bank import --disk HD10.hda --bank Piano.EB2

# Export bank
cli-anything-emaxforge bank export --disk HD10.hda --index 1 --output Piano.EB2

# List banks
cli-anything-emaxforge bank list --disk HD10.hda
```

### Sample Operations

```bash
# Convert WAV → EMAX II
cli-anything-emaxforge sample convert --input Kick.wav --output HD10.hda --bank-name "DRUMS"
```

### UI Automation

```bash
# Launch app
cli-anything-emaxforge ui launch

# Take screenshot
cli-anything-emaxforge ui screenshot --output emaxforge.png

# Verify boot wizard
cli-anything-emaxforge ui verify-boot-wizard
```

### Validation

```bash
# Validate disk structure
cli-anything-emaxforge validate check --input HD00.hda
```

## Development Loop

1. **Pick feature** from `standard tools_FEATURE_INVENTORY.md`
2. **Add CLI command** in `emaxforge_cli.py`
3. **Implement backend** in `utils/swift_backend.py` or `core/`
4. **Write test** in `tests/test_<feature>.py`
5. **Run test** → verify output
6. **Update UI** (SwiftUI) if needed
7. **Screenshot** → compare with standard tools
8. **Commit** → next feature

## Backend Strategy

### 1. Wrap Existing Swift CLIs

EmaxForge has native Swift scripts:
- `cli-create-test-disks.swift`
- `cli-import-eb2-banks.swift`
- `cli-import-samples.swift`

Harness wraps these via `utils/swift_backend.py`.

### 2. Drive GUI via AppleScript

For operations without CLI:
- UI navigation
- Screenshot capture
- Dialog verification

### 3. Parse App Output

Verify disk images, screenshots, error messages.

### 4. Generate Swift Code

For new features, generate Swift code and commit back to repo.

## Testing

```bash
# Run all tests
cd ~/clawd/EmaxForge/agent-harness
pytest -v

# Run specific test
pytest tests/test_disk_ops.py -v

# Run with coverage
pytest --cov=cli_anything.emaxforge
```

## JSON Output

All commands support `--json` for machine-readable output:

```bash
cli-anything-emaxforge --json disk info --input HD00.hda
```

Output:
```json
{
  "status": "success",
  "disk": {
    "size": 250398720,
    "size_mb": 239,
    "boot": true,
    "scsi_id": 0,
    "banks": 2,
    "free_space": 230000000
  }
}
```

## standard tools Feature Parity

See `standard tools_FEATURE_INVENTORY.md` for full feature matrix.

**Current status:**
- ✅ Phase 1: Core polish (4/4 features)
- ⏳ Phase 2: Sample workflow (0/4 features)
- ⏳ Phase 3: Advanced disk (0/4 features)
- ⏳ Phase 4: Cross-platform (0/4 features)

## Files

- `EMAXFORGE.md` - Architecture and development plan
- `standard tools_FEATURE_INVENTORY.md` - Feature matrix vs standard tools
- `setup.py` - Python package config
- `cli_anything/emaxforge/emaxforge_cli.py` - Main CLI
- `cli_anything/emaxforge/utils/swift_backend.py` - Swift script wrapper

## Status

**Created:** 2026-03-17 06:35 CET
**Version:** 0.1.0
**Features:** 0/16 implemented
**Tests:** 0 written

## Next Steps

1. ✅ Create harness structure
2. ✅ Implement CLI skeleton
3. ✅ Create Swift backend wrapper
4. ⏳ Install harness + test
5. ⏳ Implement first feature (disk create)
6. ⏳ Write first test
7. ⏳ Run dev loop on Phase 1
