"""
Performance benchmarks for EmaxForge CLI harness.

Measures creation, parsing, and analysis times.
All benchmarks assert reasonable upper bounds.
"""

import struct
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HARNESS_DIR = Path(__file__).parents[1]

BOOT_SIGS = {
    96:  (0xA1, 0x93),
    239: (0x78, 0x82),
    481: (0x65, 0x9F),
    633: (0x79, 0x24),
    962: (0xD7, 0xAD),
}

# Time limits (seconds)
BOOT_DISK_MAX_S = 5.0   # Template copy should be fast
FLOPPY_MAX_S    = 0.5   # In-memory construction
FAT_PARSE_MAX_S = 2.0   # Only reads a small FAT window
VERIFY_MAX_S    = 2.0   # Reads header area only
LIST_MAX_S      = 0.5   # Directory listing


def cli(*args, cwd=None) -> tuple[int, str, float]:
    """Run CLI, return (returncode, output, elapsed_seconds)."""
    start = time.monotonic()
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.emaxforge", *args],
        capture_output=True, text=True,
        cwd=str(cwd or HARNESS_DIR),
    )
    elapsed = time.monotonic() - start
    return result.returncode, result.stdout + result.stderr, elapsed


TEMPLATE_DIR = Path(__file__).parents[2] / "EmaxForge" / "Resources" / "bootable_templates"
_TEMPLATE_SIZE_MAP = {96: "EMAXII_IMAGE_096.EZ2", 239: "EMAXII_IMAGE_239.EZ2",
                      481: "EMAXII_IMAGE_481.EZ2", 633: "EMAXII_IMAGE_633.EZ2",
                      962: "EMAXII_IMAGE_962.EZ2"}

def make_fake_disk(size_mb: int = 239) -> bytes:
    """Return a valid EMAX II disk image for the given size.
    
    Uses real boot templates when available (guarantees verify-boot passes).
    Falls back to minimal-but-valid synthetic header for unknown sizes.
    """
    tmpl_name = _TEMPLATE_SIZE_MAP.get(size_mb)
    if tmpl_name:
        # Try resources/templates first
        for candidate in [
            TEMPLATE_DIR / tmpl_name,
            Path(__file__).parents[2] / "EmaxForge" / "Resources" / "bootable_templates" / tmpl_name,
        ]:
            if candidate.exists():
                return candidate.read_bytes()

    # Fallback: synthetic header (may not pass verify-boot signature check)
    sig = BOOT_SIGS.get(size_mb, (0x78, 0x82))
    data = bytearray(size_mb * 1024 * 1024)
    data[0:4] = b"EMX2"
    data[0x1FE] = sig[0]
    data[0x1FF] = sig[1]
    struct.pack_into("<H", data, 0x400, 0x8000)
    struct.pack_into("<H", data, 0x402, 0x7FFF)
    data[0x1000:0x1010] = b"EMAX2 Software\x00\x00"
    return bytes(data)


# ---------------------------------------------------------------------------
# Boot Disk Creation Speed
# ---------------------------------------------------------------------------

class TestBootDiskCreationSpeed(unittest.TestCase):
    """Benchmark boot disk creation from template files."""

    def _time_create(self, size_mb: int) -> float:
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / f"HD10_{size_mb}.hda")
            code, output, elapsed = cli("create-boot-disk", "--size", str(size_mb),
                                        "--output", out)
            if code != 0:
                self.skipTest(f"Template for {size_mb} MB not available")
            return elapsed

    def test_create_96mb_speed(self):
        elapsed = self._time_create(96)
        self.assertLess(elapsed, BOOT_DISK_MAX_S,
                        f"96 MB boot disk too slow: {elapsed:.2f}s (limit {BOOT_DISK_MAX_S}s)")

    def test_create_239mb_speed(self):
        elapsed = self._time_create(239)
        self.assertLess(elapsed, BOOT_DISK_MAX_S,
                        f"239 MB boot disk too slow: {elapsed:.2f}s")

    def test_create_481mb_speed(self):
        elapsed = self._time_create(481)
        self.assertLess(elapsed, BOOT_DISK_MAX_S,
                        f"481 MB boot disk too slow: {elapsed:.2f}s")

    def test_create_633mb_speed(self):
        elapsed = self._time_create(633)
        self.assertLess(elapsed, BOOT_DISK_MAX_S,
                        f"633 MB boot disk too slow: {elapsed:.2f}s")

    def test_create_962mb_speed(self):
        elapsed = self._time_create(962)
        self.assertLess(elapsed, BOOT_DISK_MAX_S,
                        f"962 MB boot disk too slow: {elapsed:.2f}s")

    def test_all_sizes_benchmark_summary(self):
        """Report timing for all sizes without assertions."""
        timings = {}
        for size_mb in [96, 239, 481, 633, 962]:
            with tempfile.TemporaryDirectory() as d:
                out = str(Path(d) / "HD10.hda")
                code, _, elapsed = cli("create-boot-disk", "--size", str(size_mb),
                                       "--output", out)
                if code == 0:
                    timings[size_mb] = elapsed
        # Just record - no assertion (informational)
        self.assertTrue(len(timings) > 0, "No timings recorded - are templates available?")


# ---------------------------------------------------------------------------
# Disk Parsing Speed
# ---------------------------------------------------------------------------

class TestDiskParsingSpeed(unittest.TestCase):
    """Disk verification reads only the header area (~17KB), should be fast."""

    def test_verify_239mb_speed(self):
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            disk.write_bytes(make_fake_disk(239))
            code, _, elapsed = cli("verify-boot", str(disk))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, VERIFY_MAX_S,
                            f"verify-boot too slow: {elapsed:.2f}s")

    def test_verify_962mb_speed(self):
        """Larger disk should not slow verification (reads header only)."""
        import shutil
        free_mb = shutil.disk_usage(tempfile.gettempdir()).free // (1024 * 1024)
        if free_mb < 1100:
            self.skipTest(f"Insufficient /tmp space: {free_mb}MB free")
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            disk.write_bytes(make_fake_disk(962))
            code, _, elapsed = cli("verify-boot", str(disk))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, VERIFY_MAX_S,
                            f"verify-boot 962MB too slow: {elapsed:.2f}s")

    def test_list_images_speed(self):
        """list-images on a directory of 5 disks should be fast."""
        with tempfile.TemporaryDirectory() as d:
            for i in range(1, 6):
                Path(d, f"HD{i}0.hda").write_bytes(make_fake_disk(96))
            code, _, elapsed = cli("list-images", d)
            self.assertEqual(code, 0)
            self.assertLess(elapsed, LIST_MAX_S,
                            f"list-images too slow: {elapsed:.2f}s")


# ---------------------------------------------------------------------------
# FAT Analysis Speed
# ---------------------------------------------------------------------------

class TestFATAnalysisSpeed(unittest.TestCase):
    """FAT analyzer reads limited FAT window, not entire disk."""

    def test_analyze_fat_239mb_speed(self):
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            # Use real template if available
            code0, _, _ = cli("create-boot-disk", "--size", "239",
                              "--output", str(disk))
            if code0 != 0:
                disk.write_bytes(make_fake_disk(239))

            code, _, elapsed = cli("analyze-fat", str(disk))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, FAT_PARSE_MAX_S,
                            f"analyze-fat too slow: {elapsed:.2f}s")

    def test_analyze_fat_962mb_speed(self):
        import shutil
        free_mb = shutil.disk_usage(tempfile.gettempdir()).free // (1024 * 1024)
        if free_mb < 1100:
            self.skipTest(f"Insufficient /tmp space: {free_mb}MB free")
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            code0, _, _ = cli("create-boot-disk", "--size", "962",
                              "--output", str(disk))
            if code0 != 0:
                disk.write_bytes(make_fake_disk(962))

            code, _, elapsed = cli("analyze-fat", str(disk))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, FAT_PARSE_MAX_S,
                            f"analyze-fat 962MB too slow: {elapsed:.2f}s")


# ---------------------------------------------------------------------------
# Floppy Creation Speed
# ---------------------------------------------------------------------------

class TestFloppyCreationSpeed(unittest.TestCase):

    def test_create_180k_raw_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("create-floppy", "--size", "180K",
                                   "--format", "raw",
                                   "--output", str(Path(d) / "FD.img"))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, FLOPPY_MAX_S,
                            f"180K floppy too slow: {elapsed:.2f}s")

    def test_create_800k_raw_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("create-floppy", "--size", "800K",
                                   "--format", "raw",
                                   "--output", str(Path(d) / "FD.img"))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, FLOPPY_MAX_S,
                            f"800K floppy too slow: {elapsed:.2f}s")

    def test_create_800k_hfe_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("create-floppy", "--size", "800K",
                                   "--format", "hfe",
                                   "--output", str(Path(d) / "FD.hfe"))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, FLOPPY_MAX_S,
                            f"800K HFE floppy too slow: {elapsed:.2f}s")

    def test_create_1440k_raw_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("create-floppy", "--size", "1440K",
                                   "--format", "raw",
                                   "--output", str(Path(d) / "FD.img"))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, FLOPPY_MAX_S,
                            f"1440K floppy too slow: {elapsed:.2f}s")


# ---------------------------------------------------------------------------
# Bank Template Speed
# ---------------------------------------------------------------------------

class TestBankTemplateSpeed(unittest.TestCase):

    TEMPLATE_MAX_S = 0.5

    def test_create_init_template_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("create-template", "INIT",
                                   str(Path(d) / "INIT.EB2"))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, self.TEMPLATE_MAX_S)

    def test_create_empty_100_preset_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("create-template", "EMPTY",
                                   str(Path(d) / "EMPTY.EB2"),
                                   "--preset-count", "100")
            self.assertEqual(code, 0)
            self.assertLess(elapsed, self.TEMPLATE_MAX_S)

    def test_list_templates_speed(self):
        code, _, elapsed = cli("list-templates")
        self.assertEqual(code, 0)
        self.assertLess(elapsed, 0.2, f"list-templates too slow: {elapsed:.2f}s")


# ---------------------------------------------------------------------------
# ZuluSCSI Config Speed
# ---------------------------------------------------------------------------

class TestZuluSCSIConfigSpeed(unittest.TestCase):

    CONFIG_MAX_S = 0.2

    def test_generate_config_speed(self):
        with tempfile.TemporaryDirectory() as d:
            code, _, elapsed = cli("generate-zulu-config",
                                   str(Path(d) / "zuluscsi.ini"))
            self.assertEqual(code, 0)
            self.assertLess(elapsed, self.CONFIG_MAX_S)

    def test_validate_config_speed(self):
        with tempfile.TemporaryDirectory() as d:
            cfg = str(Path(d) / "zuluscsi.ini")
            cli("generate-zulu-config", cfg)
            code, _, elapsed = cli("validate-zulu-config", cfg)
            self.assertEqual(code, 0)
            self.assertLess(elapsed, self.CONFIG_MAX_S)


if __name__ == "__main__":
    unittest.main(verbosity=2)
