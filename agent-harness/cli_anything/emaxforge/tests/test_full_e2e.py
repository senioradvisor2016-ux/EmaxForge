"""
Full end-to-end tests for cli-anything-emaxforge.

Tests cover complete workflows:
  1. Create floppy → verify structure → list
  2. Convert HFE → IMG
  3. Create boot disk (skipped if templates unavailable)
  4. Verify boot disk (file-level)
  5. AppleScript smoke tests (skipped in CI)
"""

import json
import subprocess
import tempfile
import unittest
import os
from pathlib import Path

TEMPLATE_DIR = Path(__file__).parents[4] / "EmaxForge" / "Resources" / "bootable_templates"
_TEMPLATE_SIZE_MAP = {96: "EMAXII_IMAGE_096.EZ2", 239: "EMAXII_IMAGE_239.EZ2",
                      481: "EMAXII_IMAGE_481.EZ2", 633: "EMAXII_IMAGE_633.EZ2",
                      962: "EMAXII_IMAGE_962.EZ2"}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

HARNESS_DIR = Path(__file__).parents[4]  # agent-harness/

def cli(*args, cwd=None) -> tuple[int, str]:
    """Run cli-anything-emaxforge as a module."""
    import sys
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.emaxforge", *args],
        capture_output=True, text=True,
        cwd=str(cwd or HARNESS_DIR),
    )
    return result.returncode, result.stdout + result.stderr


def parse_json(output: str):
    """Extract first JSON object/array from output (tolerates warning lines)."""
    for i, ch in enumerate(output):
        if ch in ("{", "["):
            depth = 0
            for j, c in enumerate(output[i:]):
                if c in ("{", "["):
                    depth += 1
                elif c in ("}", "]"):
                    depth -= 1
                    if depth == 0:
                        return json.loads(output[i: i + j + 1])
    raise ValueError(f"No JSON found in output:\n{output}")


def is_ci() -> bool:
    return os.environ.get("CI") == "true" or os.environ.get("GITHUB_ACTIONS") == "true"


def applescript_available() -> bool:
    """Check if osascript is available (macOS only, not in CI)."""
    return not is_ci() and os.path.exists("/usr/bin/osascript")


# ---------------------------------------------------------------------------
# Workflow: Floppy creation + listing
# ---------------------------------------------------------------------------

class TestFloppyWorkflow(unittest.TestCase):

    def test_create_list_raw_floppy(self):
        """Create a raw 800K floppy, then confirm it appears in list-images."""
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "FD00.img")
            code, out_text = cli("create-floppy", "--size", "800K", "--format", "raw", "--output", out)
            self.assertEqual(code, 0, f"create-floppy failed:\n{out_text}")

            code2, list_out = cli("list-images", d, "--json")
            self.assertEqual(code2, 0)
            data = parse_json(list_out)
            self.assertEqual(data["count"], 1)
            img = data["images"][0]
            self.assertEqual(img["type"], "floppy")
            self.assertAlmostEqual(img["size_bytes"], 819_200, delta=100)

    def test_create_hfe_floppy_has_magic(self):
        """HFE output should start with HFE magic bytes."""
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "FD00.hfe")
            code, out_text = cli("create-floppy", "--size", "800K", "--format", "hfe", "--output", out)
            self.assertEqual(code, 0, f"create-floppy HFE failed:\n{out_text}")
            magic = Path(out).read_bytes()[:8]
            self.assertEqual(magic, b"HXCPICFE")

    def test_create_floppy_json_output(self):
        """JSON output should contain expected fields."""
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "FD00.img")
            code, out_text = cli("create-floppy", "--size", "800K", "--format", "raw",
                                 "--output", out, "--json")
            self.assertEqual(code, 0)
            data = parse_json(out_text)
            for field in ("path", "format", "size_bytes", "tracks", "sides"):
                self.assertIn(field, data, f"Missing field: {field}")

    def test_all_floppy_sizes(self):
        """All three floppy sizes should be creatable."""
        sizes = ["180K", "800K", "1440K"]
        expected_sizes = [184_320, 819_200, 1_474_560]
        with tempfile.TemporaryDirectory() as d:
            for size, expected_bytes in zip(sizes, expected_sizes):
                out = str(Path(d) / f"FD_{size}.img")
                code, out_text = cli("create-floppy", "--size", size, "--format", "raw", "--output", out)
                self.assertEqual(code, 0, f"Size {size} failed:\n{out_text}")
                actual = Path(out).stat().st_size
                self.assertEqual(actual, expected_bytes, f"Size mismatch for {size}")


# ---------------------------------------------------------------------------
# Workflow: HFE → IMG conversion
# ---------------------------------------------------------------------------

class TestHFEConversion(unittest.TestCase):

    def test_convert_hfe_to_img(self):
        """Create HFE, convert to IMG, verify output exists and is non-empty."""
        with tempfile.TemporaryDirectory() as d:
            hfe = str(Path(d) / "test.hfe")
            img = str(Path(d) / "test.img")

            code1, _ = cli("create-floppy", "--size", "800K", "--format", "hfe", "--output", hfe)
            self.assertEqual(code1, 0)

            code2, out = cli("convert-hfe", hfe, img, "--json")
            self.assertEqual(code2, 0, f"convert-hfe failed:\n{out}")
            data = parse_json(out)
            self.assertGreater(data["size_bytes"], 0)
            self.assertTrue(Path(img).exists())


# ---------------------------------------------------------------------------
# Workflow: Boot disk verification (template-optional)
# ---------------------------------------------------------------------------

class TestBootDiskVerification(unittest.TestCase):

    def _fake_disk(self, size_mb=239) -> Path:
        """Write a minimal valid fake boot disk.
        
        Uses real boot templates when available (guarantees verify-boot passes).
        Falls back to synthetic header for edge cases.
        """
        import struct
        
        # Try real template first
        tmpl_name = _TEMPLATE_SIZE_MAP.get(size_mb)
        if tmpl_name and TEMPLATE_DIR.exists():
            tmpl_path = TEMPLATE_DIR / tmpl_name
            if tmpl_path.exists():
                tmp = tempfile.NamedTemporaryFile(suffix=".hda", delete=False)
                tmp.write(tmpl_path.read_bytes())
                tmp.close()
                return Path(tmp.name)

        # Fallback: synthetic
        size_bytes = size_mb * 1024 * 1024
        data = bytearray(size_bytes)
        data[0x1FE] = 0x78
        data[0x1FF] = 0x82
        struct.pack_into("<H", data, 0x400, 0x8000)
        struct.pack_into("<H", data, 0x402, 0x7FFF)
        data[0x1000:0x1010] = b"EMAX II OS\x00\x00\x00\x00\x00\x00"
        tmp = tempfile.NamedTemporaryFile(suffix=".hda", delete=False)
        tmp.write(bytes(data))
        tmp.close()
        return Path(tmp.name)

    def test_verify_valid_disk_passes(self):
        p = self._fake_disk()
        try:
            code, out = cli("verify-boot", str(p), "--json")
            self.assertEqual(code, 0, f"verify-boot failed:\n{out}")
            data = parse_json(out)
            self.assertTrue(data["valid"])
        finally:
            p.unlink()

    def test_verify_invalid_disk_exits_nonzero(self):
        import struct
        p = self._fake_disk()
        try:
            raw = bytearray(p.read_bytes())
            raw[0x1FE] = 0x55  # Wrong signature
            raw[0x1FF] = 0xAA
            p.write_bytes(bytes(raw))
            code, out = cli("verify-boot", str(p))
            self.assertNotEqual(code, 0, "Expected non-zero exit for invalid disk")
        finally:
            p.unlink()

    def test_verify_checks_all_fields(self):
        p = self._fake_disk()
        try:
            code, out = cli("verify-boot", str(p), "--json")
            data = parse_json(out)
            check_names = [c["name"] for c in data["checks"]]
            for expected in ("Boot signature", "FAT entry 0", "Catalog OS entry"):
                self.assertIn(expected, check_names)
        finally:
            p.unlink()


# ---------------------------------------------------------------------------
# Workflow: list-images on mixed directory
# ---------------------------------------------------------------------------

class TestListImages(unittest.TestCase):

    def test_mixed_hd_fd_directory(self):
        """list-images should correctly classify HD and FD files."""
        with tempfile.TemporaryDirectory() as d:
            import struct

            # Fake HD disk
            hd_data = bytearray(96 * 1024 * 1024)
            hd_data[0x1FE] = 0x78
            hd_data[0x1FF] = 0x82
            Path(d, "HD10.hda").write_bytes(bytes(hd_data))

            # Fake FD floppy
            Path(d, "FD00.img").write_bytes(b"\x00" * 819_200)

            code, out = cli("list-images", d, "--json")
            self.assertEqual(code, 0)
            data = parse_json(out)
            self.assertEqual(data["count"], 2)

            types = {img["filename"]: img["type"] for img in data["images"]}
            self.assertEqual(types["HD10.hda"], "hd")
            self.assertEqual(types["FD00.img"], "floppy")

    def test_boot_disk_flagged(self):
        """HD1x disks should be flagged as boot."""
        with tempfile.TemporaryDirectory() as d:
            Path(d, "HD10.hda").write_bytes(b"\x00" * (96 * 1024 * 1024))
            Path(d, "HD20.hda").write_bytes(b"\x00" * (96 * 1024 * 1024))
            code, out = cli("list-images", d, "--json")
            data = parse_json(out)
            by_name = {img["filename"]: img for img in data["images"]}
            self.assertTrue(by_name["HD10.hda"]["is_boot"])
            self.assertFalse(by_name["HD20.hda"]["is_boot"])


# ---------------------------------------------------------------------------
# AppleScript smoke tests (macOS only, skipped in CI)
# ---------------------------------------------------------------------------

@unittest.skipUnless(applescript_available(), "AppleScript tests require macOS and non-CI environment")
class TestAppleScriptSmoke(unittest.TestCase):

    SCRIPT_DIR = Path(__file__).parents[1] / "utils" / "applescript"

    def _run_script(self, name: str, *args) -> tuple[int, str]:
        script = str(self.SCRIPT_DIR / name)
        cmd = ["/usr/bin/osascript", script, *args]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.returncode, result.stdout.strip()

    @unittest.skip("Requires EmaxForge.app to be built and running")
    def test_launch_script_returns_ready_or_timeout(self):
        code, out = self._run_script("launch.applescript")
        self.assertIn(out, ("ready", "timeout"))

    def test_script_files_exist(self):
        """All expected AppleScript files should exist."""
        expected = [
            "launch.applescript",
            "create_boot_disk.applescript",
            "create_floppy.applescript",
            "verify_image.applescript",
            "dump_ui.applescript",
        ]
        for script in expected:
            p = self.SCRIPT_DIR / script
            self.assertTrue(p.exists(), f"Missing script: {script}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
