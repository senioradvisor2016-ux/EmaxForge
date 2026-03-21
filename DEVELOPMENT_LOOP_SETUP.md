# EmaxForge Development Loop - CLI-Anything Setup

**Created:** 2026-03-17 06:45 CET
**Status:** ✅ Ready for first iteration

## What's Installed

### 1. CLI-Anything Harness (`agent-harness/`)

Python package that wraps EmaxForge with CLI interface:

```
agent-harness/
├── cli_anything/emaxforge/
│   ├── emaxforge_cli.py        # Click CLI (main entry point)
│   ├── utils/swift_backend.py  # Swift script wrapper
│   ├── core/                    # Business logic (to be implemented)
│   └── tests/                   # Test suite (to be implemented)
├── venv/                        # Python virtual environment
├── emaxforge-cli                # Wrapper script (activates venv)
└── setup.py                     # Package config
```

**Installation:**
```bash
cd ~/clawd/EmaxForge/agent-harness
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

**Usage:**
```bash
# Via wrapper (auto-activates venv)
~/clawd/EmaxForge/agent-harness/emaxforge-cli --help

# Or activate venv manually
cd ~/clawd/EmaxForge/agent-harness
source venv/bin/activate
cli-anything-emaxforge --help
```

### 2. Dev Loop Script

Automated development workflow:

**Location:** `~/clawd/EmaxForge/dev-loop-cli-anything.sh`

**Usage:**
```bash
cd ~/clawd/EmaxForge
./dev-loop-cli-anything.sh disk-create
./dev-loop-cli-anything.sh bank-import
./dev-loop-cli-anything.sh sample-convert
```

**What it does:**
1. ✅ Checks CLI harness installed
2. ✅ Builds EmaxForge.app (`./build.sh`)
3. ✅ Runs CLI test for feature
4. ✅ Launches UI for manual verification
5. ✅ Takes screenshot
6. ✅ Prints next steps

## Available CLI Commands

```bash
# Disk operations
emaxforge-cli disk create --size 239 --boot --output HD00.hda
emaxforge-cli disk format --input HD10.hda --quick
emaxforge-cli disk info --input HD00.hda

# Bank operations
emaxforge-cli bank import --disk HD10.hda --bank Piano.EB2
emaxforge-cli bank export --disk HD10.hda --index 1 --output Piano.EB2
emaxforge-cli bank list --disk HD10.hda

# Sample operations
emaxforge-cli sample convert --input Kick.wav --output HD10.hda

# UI automation
emaxforge-cli ui launch
emaxforge-cli ui screenshot --output emaxforge.png

# Validation
emaxforge-cli validate check --input HD00.hda

# REPL mode
emaxforge-cli repl

# JSON output (for all commands)
emaxforge-cli --json disk info --input HD00.hda
```

## Development Workflow

### Iterative Feature Development

**Goal:** Build standard tools features one at a time with CLI-driven TDD

**Process:**

1. **Pick feature** from `standard tools_FEATURE_INVENTORY.md`
   - Example: "Export banks to .EB2 files"

2. **Add CLI command** (if not exists)
   - Edit `agent-harness/cli_anything/emaxforge/emaxforge_cli.py`
   - Add `@bank.command()` function

3. **Implement backend**
   - Option A: Wrap existing Swift CLI (`utils/swift_backend.py`)
   - Option B: Create new Swift script in repo root
   - Option C: Drive UI via AppleScript (`utils/ui_automation.py`)

4. **Write test**
   - Create `agent-harness/cli_anything/emaxforge/tests/test_<feature>.py`
   - Use pytest fixtures

5. **Run dev loop**
   ```bash
   ./dev-loop-cli-anything.sh <feature>
   ```

6. **Verify**
   - Check CLI output (JSON or text)
   - Verify screenshot vs standard tools
   - Test on real disk image

7. **Commit**
   ```bash
   git add .
   git commit -m "feat: Add bank export (.EB2)"
   ```

8. **Repeat** for next feature

### Example: Implementing "Disk Create"

**Current status:** CLI skeleton exists, backend returns "not_implemented"

**Steps:**

1. **Modify existing Swift script**
   ```bash
   # Edit cli-create-test-disks.swift
   # Add command-line arguments: --size, --boot, --output
   ```

2. **Update Swift backend wrapper**
   ```python
   # Edit agent-harness/cli_anything/emaxforge/utils/swift_backend.py
   def create_disk(self, output, size_mb, boot, scsi_id):
       args = [
           "--size", str(size_mb),
           "--output", str(output),
           "--scsi-id", str(scsi_id),
       ]
       if boot:
           args.append("--boot")
       
       return self._run_swift("cli-create-test-disks.swift", args)
   ```

3. **Wire up CLI command**
   ```python
   # Edit emaxforge_cli.py
   from .utils.swift_backend import SwiftBackend
   
   @disk.command()
   def create(ctx, size, boot, output, scsi_id):
       backend = SwiftBackend()
       result = backend.create_disk(output, int(size), boot, scsi_id)
       
       if ctx.obj.get("json"):
           click.echo(json.dumps(result, indent=2))
       else:
           if result["success"]:
               click.echo(f"✅ Created {output}")
           else:
               click.echo(f"❌ {result['error']}")
   ```

4. **Test**
   ```bash
   ./dev-loop-cli-anything.sh disk-create
   ```

5. **Verify**
   - CLI creates HD00.hda
   - Screenshot shows disk in EmaxForge
   - Disk boots on EMAX II (hardware test)

## Feature Priority (Phase 1)

From `standard tools_FEATURE_INVENTORY.md`:

1. ✅ **Export banks (.EB2)** - verify existing implementation
2. ⏳ **Sample export (WAV)** - implement + test
3. ⏳ **Inspector panel** - show bank/sample details
4. ⏳ **Multi-select** - bulk delete/export

## Documentation Files

- `EMAXFORGE.md` - CLI-Anything architecture
- `standard tools_FEATURE_INVENTORY.md` - Feature matrix (standard tools vs EmaxForge)
- `agent-harness/README.md` - Installation + usage
- `~/clawd/standard tools_manual.txt` - standard tools reference (38k lines)

## Testing

```bash
cd ~/clawd/EmaxForge/agent-harness
source venv/bin/activate

# Run all tests
pytest -v

# Run specific test
pytest tests/test_disk_ops.py::test_create_boot_disk -v

# Run with coverage
pytest --cov=cli_anything.emaxforge --cov-report=html
```

## Next Steps

1. ✅ Harness structure created
2. ✅ CLI skeleton implemented
3. ✅ Swift backend wrapper ready
4. ✅ Dev loop script ready
5. ⏳ **First feature: Implement disk create backend**
6. ⏳ Write first test
7. ⏳ Run first dev loop iteration
8. ⏳ Verify + commit
9. ⏳ Move to next feature (bank export)

## Status

**Harness:** ✅ Installed
**CLI:** ✅ Working (skeleton)
**Backend:** ⏳ Needs implementation
**Tests:** ⏳ Not written yet
**Features:** 0/13 Phase 1 complete

**Ready for:** First dev loop iteration!
