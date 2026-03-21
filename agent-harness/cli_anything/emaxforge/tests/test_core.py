"""
Unit tests for cli-anything-emaxforge core modules.
Tests run headless (no GUI, no EmaxForge app required).
"""

import json
import struct
import tempfile
import unittest
from pathlib import Path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

TEMPLATE_DIR = Path(__file__).parents[4] / "EmaxForge" / "Resources" / "bootable_templates"
_TEMPLATE_SIZE_MAP = {96: "EMAXII_IMAGE_096.EZ2", 239: "EMAXII_IMAGE_239.EZ2",
                      481: "EMAXII_IMAGE_481.EZ2", 633: "EMAXII_IMAGE_633.EZ2",
                      962: "EMAXII_IMAGE_962.EZ2"}

def _make_fake_disk(size_mb: int = 239, boot_sig: tuple = (0x78, 0x82),
                    fat0: int = 0x8000, has_catalog: bool = True) -> bytes:
    """Build a minimal fake EMAX II disk image for testing.
    
    Uses real boot templates when available (guarantees verify-boot passes).
    Falls back to synthetic header for edge case corruption tests.
    """
    # For edge case tests with corruption, use synthetic
    if boot_sig != (0x78, 0x82) or fat0 != 0x8000 or not has_catalog:
        size_bytes = size_mb * 1024 * 1024
        data = bytearray(size_bytes)
        data[0x1FE] = boot_sig[0]
        data[0x1FF] = boot_sig[1]
        struct.pack_into("<H", data, 0x400, fat0)
        struct.pack_into("<H", data, 0x402, 0x7FFF)
        if has_catalog:
            data[0x1000:0x1010] = b"EMAX II OS\x00\x00\x00\x00\x00\x00"
        return bytes(data)

    # Otherwise use real template
    tmpl_name = _TEMPLATE_SIZE_MAP.get(size_mb)
    if tmpl_name and TEMPLATE_DIR.exists():
        tmpl_path = TEMPLATE_DIR / tmpl_name
        if tmpl_path.exists():
            return tmpl_path.read_bytes()

    # Final fallback
    size_bytes = size_mb * 1024 * 1024
    data = bytearray(size_bytes)

    # Boot signature at 0x1FE
    data[0x1FE] = boot_sig[0]
    data[0x1FF] = boot_sig[1]

    # FAT at 0x400
    struct.pack_into("<H", data, 0x400, fat0)       # FAT[0]
    struct.pack_into("<H", data, 0x402, 0x7FFF)     # FAT[1] end-of-chain (OS)

    # Catalog OS entry at 0x1000
    if has_catalog:
        os_name = b"EMAX II OS\x00\x00\x00\x00\x00\x00"
        data[0x1000: 0x1000 + len(os_name)] = os_name

    return bytes(data)


# ---------------------------------------------------------------------------
# boot_creator tests
# ---------------------------------------------------------------------------

class TestVerifyBootDisk(unittest.TestCase):

    def _write_tmp(self, data: bytes) -> Path:
        tmp = tempfile.NamedTemporaryFile(suffix=".hda", delete=False)
        tmp.write(data)
        tmp.close()
        return Path(tmp.name)

    def test_valid_disk_passes_all_checks(self):
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = self._write_tmp(_make_fake_disk())
        result = verify_boot_disk(str(p))
        self.assertTrue(result["valid"], f"Expected valid, checks: {result['checks']}")
        p.unlink()

    def test_wrong_boot_signature_fails(self):
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = self._write_tmp(_make_fake_disk(boot_sig=(0x55, 0xAA)))  # PC signature
        result = verify_boot_disk(str(p))
        self.assertFalse(result["valid"])
        sig_check = next(c for c in result["checks"] if "Boot signature" in c["name"])
        self.assertFalse(sig_check["passed"])
        p.unlink()

    def test_bad_fat_entry_fails(self):
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = self._write_tmp(_make_fake_disk(fat0=0x0000))
        result = verify_boot_disk(str(p))
        fat_check = next(c for c in result["checks"] if "FAT entry 0" in c["name"])
        self.assertFalse(fat_check["passed"])
        p.unlink()

    def test_missing_file_raises(self):
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        with self.assertRaises(FileNotFoundError):
            verify_boot_disk("/tmp/nonexistent_disk_xyz.hda")

    def test_checks_list_contains_expected_keys(self):
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = self._write_tmp(_make_fake_disk())
        result = verify_boot_disk(str(p))
        names = [c["name"] for c in result["checks"]]
        self.assertIn("Boot signature", names)
        self.assertIn("FAT entry 0", names)
        self.assertIn("Catalog OS entry", names)
        self.assertIn("File size", names)
        p.unlink()


class TestListImages(unittest.TestCase):

    def test_lists_hda_files(self):
        from cli_anything.emaxforge.core.boot_creator import list_images
        with tempfile.TemporaryDirectory() as d:
            Path(d, "HD10.hda").write_bytes(_make_fake_disk())
            Path(d, "HD20.hda").write_bytes(_make_fake_disk())
            result = list_images(d)
            self.assertEqual(result["count"], 2)
            names = [i["filename"] for i in result["images"]]
            self.assertIn("HD10.hda", names)
            self.assertIn("HD20.hda", names)

    def test_identifies_floppy_files(self):
        from cli_anything.emaxforge.core.boot_creator import list_images
        with tempfile.TemporaryDirectory() as d:
            Path(d, "FD00.img").write_bytes(b"\x00" * 819_200)
            result = list_images(d)
            self.assertEqual(result["count"], 1)
            self.assertEqual(result["images"][0]["type"], "floppy")

    def test_empty_directory(self):
        from cli_anything.emaxforge.core.boot_creator import list_images
        with tempfile.TemporaryDirectory() as d:
            result = list_images(d)
            self.assertEqual(result["count"], 0)

    def test_missing_directory_raises(self):
        from cli_anything.emaxforge.core.boot_creator import list_images
        with self.assertRaises(FileNotFoundError):
            list_images("/tmp/no_such_dir_xyz_abc/")


# ---------------------------------------------------------------------------
# floppy_manager tests
# ---------------------------------------------------------------------------

class TestCreateFloppy(unittest.TestCase):

    def test_create_raw_floppy_800k(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy, FLOPPY_SIZES
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "FD00.img")
            result = create_floppy("800K", out, format_type="raw")
            self.assertTrue(Path(out).exists())
            self.assertEqual(result["size_bytes"], FLOPPY_SIZES["800K"]["bytes"])
            self.assertEqual(result["format"], "raw")

    def test_create_hfe_floppy(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy, HFE_MAGIC
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "FD00.hfe")
            result = create_floppy("800K", out, format_type="hfe")
            self.assertTrue(Path(out).exists())
            self.assertEqual(result["format"], "hfe")
            # Check HFE magic bytes
            data = Path(out).read_bytes()
            self.assertEqual(data[:8], HFE_MAGIC)

    def test_create_180k_single_density(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "FD01.img")
            result = create_floppy("180K", out, format_type="raw")
            self.assertIn("180", result["size_label"])

    def test_invalid_size_raises(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "bad.img")
            with self.assertRaises(ValueError):
                create_floppy("999K", out)

    def test_all_valid_sizes(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy, FLOPPY_SIZES
        with tempfile.TemporaryDirectory() as d:
            for size in FLOPPY_SIZES:
                out = str(Path(d) / f"test_{size}.img")
                result = create_floppy(size, out, format_type="raw")
                self.assertTrue(Path(out).exists(), f"File not created for size {size}")


class TestFloppySizeDetection(unittest.TestCase):

    def test_detect_800k(self):
        from cli_anything.emaxforge.core.floppy_manager import _detect_size
        spec = _detect_size(819_200)
        self.assertIsNotNone(spec)
        self.assertIn("800", spec["label"])

    def test_detect_1440k(self):
        from cli_anything.emaxforge.core.floppy_manager import _detect_size
        spec = _detect_size(1_474_560)
        self.assertIsNotNone(spec)
        self.assertIn("1.44", spec["label"])

    def test_unknown_size_returns_none(self):
        from cli_anything.emaxforge.core.floppy_manager import _detect_size
        spec = _detect_size(12_345_678)
        self.assertIsNone(spec)


class TestListFloppies(unittest.TestCase):

    def test_finds_fd_prefixed_files(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy, list_floppies
        with tempfile.TemporaryDirectory() as d:
            create_floppy("800K", str(Path(d) / "FD00.img"), format_type="raw")
            create_floppy("800K", str(Path(d) / "FD10.img"), format_type="raw")
            result = list_floppies(d)
            self.assertEqual(result["count"], 2)

    def test_finds_hfe_files(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy, list_floppies
        with tempfile.TemporaryDirectory() as d:
            create_floppy("800K", str(Path(d) / "EMAX_Floppy.hfe"), format_type="hfe")
            result = list_floppies(d)
            self.assertEqual(result["count"], 1)
            self.assertEqual(result["images"][0]["format"], "hfe")

    def test_missing_directory_raises(self):
        from cli_anything.emaxforge.core.floppy_manager import list_floppies
        with self.assertRaises(FileNotFoundError):
            list_floppies("/tmp/no_such_dir_floppies/")


class TestConvertHFE(unittest.TestCase):

    def test_convert_roundtrip(self):
        from cli_anything.emaxforge.core.floppy_manager import create_floppy, convert_hfe_to_img
        with tempfile.TemporaryDirectory() as d:
            hfe_path = str(Path(d) / "test.hfe")
            img_path = str(Path(d) / "test.img")
            create_floppy("800K", hfe_path, format_type="hfe")
            result = convert_hfe_to_img(hfe_path, img_path)
            self.assertTrue(Path(img_path).exists())
            self.assertGreater(result["size_bytes"], 0)

    def test_invalid_hfe_raises(self):
        from cli_anything.emaxforge.core.floppy_manager import convert_hfe_to_img
        with tempfile.TemporaryDirectory() as d:
            bad = Path(d) / "bad.hfe"
            bad.write_bytes(b"NOT_HFE_DATA" * 100)
            with self.assertRaises(ValueError):
                convert_hfe_to_img(str(bad), str(Path(d) / "out.img"))


# ---------------------------------------------------------------------------
# CLI integration tests (subprocess)
# ---------------------------------------------------------------------------

class TestCLISubprocess(unittest.TestCase):
    """Run CLI commands as subprocesses to test the installed entry point."""

    def _run(self, *args) -> tuple[int, str]:
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, "-m", "cli_anything.emaxforge", *args],
            capture_output=True, text=True,
            cwd=str(Path(__file__).parents[4])  # agent-harness/
        )
        return result.returncode, result.stdout + result.stderr

    @staticmethod
    def _parse_json(output: str):
        """Extract first JSON object/array from output (tolerates warning lines)."""
        # Find start of JSON
        for i, ch in enumerate(output):
            if ch in ("{", "["):
                candidate = output[i:]
                # Find the matching end by trying progressively shorter strings
                depth = 0
                for j, c in enumerate(candidate):
                    if c in ("{", "["):
                        depth += 1
                    elif c in ("}", "]"):
                        depth -= 1
                        if depth == 0:
                            return json.loads(candidate[: j + 1])
        raise ValueError(f"No JSON found in output:\n{output}")

    def test_help_runs(self):
        code, out = self._run("--help")
        self.assertEqual(code, 0)
        self.assertIn("EmaxForge", out)

    def test_version_runs(self):
        code, out = self._run("--version")
        self.assertEqual(code, 0)

    def test_create_floppy_cmd(self):
        with tempfile.TemporaryDirectory() as d:
            out_path = str(Path(d) / "FD00.img")
            code, output = self._run("create-floppy", "--size", "800K", "--format", "raw", "--output", out_path)
            self.assertEqual(code, 0, f"CLI failed:\n{output}")
            self.assertTrue(Path(out_path).exists())

    def test_create_floppy_json(self):
        with tempfile.TemporaryDirectory() as d:
            out_path = str(Path(d) / "FD00.hfe")
            code, output = self._run("create-floppy", "--size", "800K", "--format", "hfe",
                                     "--output", out_path, "--json")
            self.assertEqual(code, 0, f"CLI failed:\n{output}")
            data = self._parse_json(output)
            self.assertEqual(data["format"], "hfe")

    def test_list_images_cmd(self):
        with tempfile.TemporaryDirectory() as d:
            # Create dummy HD and FD files
            Path(d, "HD10.hda").write_bytes(_make_fake_disk())
            Path(d, "FD00.img").write_bytes(b"\x00" * 819_200)
            code, output = self._run("list-images", d, "--json")
            self.assertEqual(code, 0, f"CLI failed:\n{output}")
            data = self._parse_json(output)
            self.assertEqual(data["count"], 2)

    def test_verify_boot_valid(self):
        with tempfile.TemporaryDirectory() as d:
            disk_path = str(Path(d) / "HD10.hda")
            Path(disk_path).write_bytes(_make_fake_disk())
            code, output = self._run("verify-boot", disk_path, "--json")
            self.assertEqual(code, 0, f"CLI failed:\n{output}")
            data = self._parse_json(output)
            self.assertTrue(data["valid"])

    def test_verify_boot_invalid_exits_1(self):
        with tempfile.TemporaryDirectory() as d:
            disk_path = str(Path(d) / "bad.hda")
            Path(disk_path).write_bytes(_make_fake_disk(boot_sig=(0x55, 0xAA)))
            code, _ = self._run("verify-boot", disk_path)
            self.assertNotEqual(code, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
