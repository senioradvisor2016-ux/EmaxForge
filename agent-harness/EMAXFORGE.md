# EmaxForge - CLI-Anything Development Harness

**App:** EmaxForge (SwiftUI macOS EMAX II disk manager)
**Location:** `~/clawd/EmaxForge/`
**Build:** `./build.sh` → `.build/EmaxForge.app` (~16s)
**CLI:** `cli-anything-emaxforge` (this harness)

## Purpose

CLI-Anything wrapper for EmaxForge to enable:
- Automated testing of SwiftUI app via CLI
- Feature development driven by CLI commands
- UI verification via screenshots
- Integration with standard tools reference manual

## Architecture

```
EmaxForge/
├── EmaxForge/              # SwiftUI app source
│   ├── Models/            # ImageFile, BankFile, etc.
│   ├── Views/             # Main UI components
│   ├── Services/          # ImageCreator, Parser, etc.
│   └── Utils/             # Helpers
├── agent-harness/         # CLI-Anything harness (this)
│   ├── cli_anything/
│   │   └── emaxforge/
│   │       ├── __init__.py
│   │       ├── __main__.py
│   │       ├── emaxforge_cli.py  # Click CLI
│   │       ├── core/              # Business logic
│   │       ├── utils/             # Backend wrappers
│   │       └── tests/             # Test suite
│   └── setup.py
└── tests/                 # Swift test suite
```

## Backend Strategy

EmaxForge has **native CLI scripts** already:
- `cli-create-test-disks.swift` - Create disk images
- `cli-import-eb2-banks.swift` - Import banks
- `cli-import-samples.swift` - Convert WAV → EMAX II

**Harness approach:**
1. **Wrap existing Swift CLIs** where available
2. **Drive GUI via AppleScript** for operations without CLI
3. **Parse app output** (disk files, screenshots) for verification
4. **Generate Swift code** for new features (commit back to repo)

## CLI Commands (Planned)

```bash
# Disk operations
cli-anything-emaxforge disk create --size 239 --boot --output HD00.hda
cli-anything-emaxforge disk format --input HD10.hda --quick
cli-anything-emaxforge disk info --input HD00.hda

# Bank operations
cli-anything-emaxforge bank import --disk HD10.hda --bank Piano.EB2
cli-anything-emaxforge bank export --disk HD10.hda --index 1 --output Piano.EB2
cli-anything-emaxforge bank list --disk HD10.hda

# Sample operations
cli-anything-emaxforge sample convert --input Kick.wav --output HD10.hda
cli-anything-emaxforge sample export --disk HD10.hda --bank 1 --sample 0 --output Kick.wav

# Validation
cli-anything-emaxforge validate --input HD00.hda
cli-anything-emaxforge repair --input HD00.hda --output HD00_fixed.hda

# UI testing
cli-anything-emaxforge ui launch
cli-anything-emaxforge ui screenshot --output emaxforge.png
cli-anything-emaxforge ui verify-boot-wizard
```

## Development Loop

1. **Pick feature** from `standard tools_FEATURE_INVENTORY.md`
2. **Add CLI command** to `emaxforge_cli.py`
3. **Implement backend** in `core/` (wrap Swift or AppleScript)
4. **Write test** in `tests/test_<feature>.py`
5. **Run test** → verify CLI output
6. **Update UI** (SwiftUI code) if needed
7. **Screenshot verification** → compare with standard tools
8. **Commit** → move to next feature

## standard tools Reference Integration

Use `~/clawd/standard tools_manual.txt` (38k lines) as spec:
- Section 3: Feature list
- Section 4: Data model (banks, samples, disks)
- Section 6: Copy/import workflows
- Section 7: Conversion algorithms

Map standard tools workflows → EmaxForge CLI commands.

## Testing Strategy

### Unit Tests (`test_core.py`)
- Image creation (all sizes)
- Bank parsing (.EB2 format)
- Sample conversion (WAV → EMAX II)
- Metadata validation

### E2E Tests (`test_full_e2e.py`)
- Create boot disk
- Import banks
- Launch UI
- Screenshot verification
- Disk verification (boot on EMAX II simulator)

### UI Tests (`test_ui.py`)
- AppleScript automation
- Screenshot comparison
- Navigation flows
- Error dialogs

## Next Steps

1. ✅ Create harness structure
2. ⏳ Implement `emaxforge_cli.py` skeleton
3. ⏳ Wrap existing Swift CLIs
4. ⏳ Add AppleScript bridge for GUI
5. ⏳ Write first test (disk creation)
6. ⏳ Run dev loop on Phase 1 features

## Status

**Created:** 2026-03-17 06:35 CET
**Features implemented:** 0/13 (Phase 1)
**Tests written:** 0
**Lines of code:** ~500 (harness skeleton)
