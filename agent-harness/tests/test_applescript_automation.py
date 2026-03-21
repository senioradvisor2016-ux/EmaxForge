"""
AppleScript GUI automation tests for EmaxForge.app.

Tests that actually drive the GUI are skipped when:
  - Not on macOS
  - EmaxForge.app is not running / not built
  - Running in CI (CI=true)

Headless checks (script file existence, osascript availability) always run.
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HARNESS_DIR = Path(__file__).parents[1]
SCRIPT_DIR = HARNESS_DIR / "cli_anything" / "emaxforge" / "utils" / "applescript"


def is_ci() -> bool:
    return os.environ.get("CI") == "true" or os.environ.get("GITHUB_ACTIONS") == "true"


def is_macos() -> bool:
    return sys.platform == "darwin"


def osascript_available() -> bool:
    return is_macos() and Path("/usr/bin/osascript").exists()


def app_running() -> bool:
    """Return True if EmaxForge.app process is currently running."""
    if not is_macos():
        return False
    result = subprocess.run(
        ["pgrep", "-x", "EmaxForge"],
        capture_output=True, text=True
    )
    return result.returncode == 0


def run_applescript(script_path: str, *args, timeout: int = 30) -> tuple[int, str]:
    cmd = ["/usr/bin/osascript", script_path, *args]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return result.returncode, result.stdout.strip() + result.stderr.strip()


def run_applescript_inline(script: str, timeout: int = 30) -> tuple[int, str]:
    result = subprocess.run(
        ["/usr/bin/osascript", "-e", script],
        capture_output=True, text=True, timeout=timeout
    )
    return result.returncode, result.stdout.strip()


# ---------------------------------------------------------------------------
# Script File Presence (always runs)
# ---------------------------------------------------------------------------

class TestAppleScriptFiles(unittest.TestCase):
    """Verify all AppleScript helper files are present."""

    EXPECTED_SCRIPTS = [
        "launch.applescript",
        "create_boot_disk.applescript",
        "create_floppy.applescript",
        "verify_image.applescript",
        "dump_ui.applescript",
    ]

    def test_script_directory_exists(self):
        self.assertTrue(SCRIPT_DIR.exists(),
                        f"AppleScript dir missing: {SCRIPT_DIR}")

    def test_all_expected_scripts_exist(self):
        for name in self.EXPECTED_SCRIPTS:
            p = SCRIPT_DIR / name
            self.assertTrue(p.exists(), f"Missing AppleScript: {name}")

    def test_scripts_are_non_empty(self):
        for name in self.EXPECTED_SCRIPTS:
            p = SCRIPT_DIR / name
            if p.exists():
                self.assertGreater(p.stat().st_size, 0,
                                   f"Empty script file: {name}")

    def test_scripts_have_tell_application(self):
        """Each script should have at least one 'tell application' block."""
        for name in self.EXPECTED_SCRIPTS:
            p = SCRIPT_DIR / name
            if p.exists():
                content = p.read_text()
                self.assertIn("tell application", content,
                              f"{name} missing 'tell application'")


# ---------------------------------------------------------------------------
# osascript Availability
# ---------------------------------------------------------------------------

@unittest.skipUnless(osascript_available(), "osascript requires macOS")
class TestOsascriptAvailability(unittest.TestCase):

    def test_osascript_version(self):
        """osascript should return version info."""
        result = subprocess.run(
            ["/usr/bin/osascript", "--version"],
            capture_output=True, text=True
        )
        # --version exits 1 but prints something
        self.assertIn("osascript", result.stdout + result.stderr)

    def test_simple_arithmetic(self):
        """Basic osascript execution."""
        code, out = run_applescript_inline("return 2 + 2")
        self.assertEqual(code, 0, f"osascript failed: {out}")
        self.assertIn("4", out)

    def test_string_result(self):
        code, out = run_applescript_inline('return "EmaxForge"')
        self.assertEqual(code, 0)
        self.assertIn("EmaxForge", out)


# ---------------------------------------------------------------------------
# GUI Smoke Tests (require running app)
# ---------------------------------------------------------------------------

@unittest.skipUnless(
    osascript_available() and not is_ci(),
    "GUI tests require macOS non-CI environment"
)
class TestGUISmoke(unittest.TestCase):
    """
    Smoke tests that check EmaxForge.app is accessible via accessibility APIs.
    Skipped if the app is not running.
    """

    def setUp(self):
        if not app_running():
            self.skipTest("EmaxForge.app is not running")

    def test_app_is_accessible(self):
        """Verify app responds to accessibility queries."""
        script = (
            'tell application "System Events" to '
            'return exists process "EmaxForge"'
        )
        code, out = run_applescript_inline(script)
        self.assertEqual(code, 0)
        self.assertIn("true", out.lower())

    def test_app_has_windows(self):
        """App should have at least one window open."""
        script = (
            'tell application "System Events" to tell process "EmaxForge" '
            'to return count of windows'
        )
        code, out = run_applescript_inline(script)
        self.assertEqual(code, 0)
        try:
            count = int(out.strip())
            self.assertGreater(count, 0, "No windows found")
        except ValueError:
            self.fail(f"Expected integer window count, got: {out!r}")

    def test_app_frontmost(self):
        """Bring EmaxForge to front and verify."""
        activate_script = 'tell application "EmaxForge" to activate'
        run_applescript_inline(activate_script)
        check_script = (
            'tell application "System Events" to '
            'return frontmost of process "EmaxForge"'
        )
        code, out = run_applescript_inline(check_script)
        self.assertEqual(code, 0)
        self.assertIn("true", out.lower())


# ---------------------------------------------------------------------------
# Boot Disk Wizard (requires running app + built features)
# ---------------------------------------------------------------------------

@unittest.skipUnless(
    osascript_available() and not is_ci(),
    "Wizard tests require macOS non-CI environment"
)
class TestBootDiskWizardScript(unittest.TestCase):
    """Test the create_boot_disk AppleScript wrapper."""

    SCRIPT = str(SCRIPT_DIR / "create_boot_disk.applescript")

    def setUp(self):
        if not (SCRIPT_DIR / "create_boot_disk.applescript").exists():
            self.skipTest("create_boot_disk.applescript not found")

    def test_script_syntax_valid(self):
        """Compile the script to check syntax (no execution)."""
        result = subprocess.run(
            ["/usr/bin/osacompile", "-o", "/dev/null", self.SCRIPT],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"Syntax error in create_boot_disk.applescript:\n{result.stderr}")

    @unittest.skip("Requires EmaxForge.app to be running with wizard available")
    def test_boot_disk_wizard_creates_file(self):
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "test_boot.hda")
            code, output = run_applescript(self.SCRIPT, "239", out)
            self.assertEqual(code, 0, f"Wizard script failed: {output}")
            self.assertTrue(Path(out).exists(), "Boot disk not created by wizard")


# ---------------------------------------------------------------------------
# Floppy Wizard Script
# ---------------------------------------------------------------------------

@unittest.skipUnless(
    osascript_available() and not is_ci(),
    "Floppy tests require macOS non-CI environment"
)
class TestFloppyWizardScript(unittest.TestCase):

    SCRIPT = str(SCRIPT_DIR / "create_floppy.applescript")

    def setUp(self):
        if not (SCRIPT_DIR / "create_floppy.applescript").exists():
            self.skipTest("create_floppy.applescript not found")

    def test_script_syntax_valid(self):
        result = subprocess.run(
            ["/usr/bin/osacompile", "-o", "/dev/null", self.SCRIPT],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"Syntax error in create_floppy.applescript:\n{result.stderr}")

    @unittest.skip("Requires EmaxForge.app to be running")
    def test_floppy_wizard_creates_file(self):
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "test.hfe")
            code, output = run_applescript(self.SCRIPT, "800K", out)
            self.assertEqual(code, 0, f"Floppy wizard failed: {output}")
            self.assertTrue(Path(out).exists())


# ---------------------------------------------------------------------------
# Verify Image Script
# ---------------------------------------------------------------------------

@unittest.skipUnless(
    osascript_available() and not is_ci(),
    "Verify tests require macOS non-CI environment"
)
class TestVerifyImageScript(unittest.TestCase):

    SCRIPT = str(SCRIPT_DIR / "verify_image.applescript")

    def setUp(self):
        if not (SCRIPT_DIR / "verify_image.applescript").exists():
            self.skipTest("verify_image.applescript not found")

    def test_script_syntax_valid(self):
        result = subprocess.run(
            ["/usr/bin/osacompile", "-o", "/dev/null", self.SCRIPT],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"Syntax error: {result.stderr}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
