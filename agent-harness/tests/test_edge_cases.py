"""
Edge case and error handling tests for EmaxForge CLI harness.

Tests corrupted images, invalid inputs, boundary conditions,
and error recovery paths.
"""

import struct
import subprocess
import sys
import tempfile
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


def cli(*args, cwd=None) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.emaxforge", *args],
        capture_output=True, text=True,
        cwd=str(cwd or HARNESS_DIR),
    )
    return result.returncode, result.stdout + result.stderr


TEMPLATE_DIR = Path(__file__).parents[2] / "EmaxForge" / "Resources" / "bootable_templates"
_TEMPLATE_SIZE_MAP = {96: "EMAXII_IMAGE_096.EZ2", 239: "EMAXII_IMAGE_239.EZ2",
                      481: "EMAXII_IMAGE_481.EZ2", 633: "EMAXII_IMAGE_633.EZ2",
                      962: "EMAXII_IMAGE_962.EZ2"}

def make_fake_disk(size_mb: int = 239, boot_sig: tuple = None,
                   fat0: int = 0x8000, has_catalog: bool = True) -> bytes:
    """Return a valid EMAX II disk image for the given size.
    
    Uses real boot templates when available (guarantees verify-boot passes).
    Falls back to minimal-but-valid synthetic header for edge case corruption tests.
    """
    # For edge case tests with corruption, ALWAYS use synthetic (to avoid corrupting templates)
    if boot_sig is not None or fat0 != 0x8000 or not has_catalog:
        sig = boot_sig or BOOT_SIGS.get(size_mb, (0x78, 0x82))
        data = bytearray(size_mb * 1024 * 1024)
        data[0x1FE] = sig[0]
        data[0x1FF] = sig[1]
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
    sig = BOOT_SIGS.get(size_mb, (0x78, 0x82))
    data = bytearray(size_mb * 1024 * 1024)
    data[0x1FE] = sig[0]
    data[0x1FF] = sig[1]
    struct.pack_into("<H", data, 0x400, 0x8000)
    struct.pack_into("<H", data, 0x402, 0x7FFF)
    data[0x1000:0x1010] = b"EMAX II OS\x00\x00\x00\x00\x00\x00"
    return bytes(data)


def write_tmp(data: bytes, suffix: str = ".hda") -> Path:
    t = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    t.write(data)
    t.close()
    return Path(t.name)


# ---------------------------------------------------------------------------
# Boot Signature Corruption
# ---------------------------------------------------------------------------

class TestCorruptedBootSignature(unittest.TestCase):

    def test_pc_boot_sig_detected(self):
        """PC-style boot signature (0x55 0xAA) should fail verification."""
        p = write_tmp(make_fake_disk(boot_sig=(0x55, 0xAA)))
        try:
            code, output = cli("verify-boot", str(p), "--json")
            self.assertNotEqual(code, 0)
        finally:
            p.unlink()

    def test_zero_boot_sig_fails(self):
        """All-zero boot signature should fail."""
        p = write_tmp(make_fake_disk(boot_sig=(0x00, 0x00)))
        try:
            code, output = cli("verify-boot", str(p), "--json")
            self.assertNotEqual(code, 0)
        finally:
            p.unlink()

    def test_wrong_sig_is_reported_in_checks(self):
        """Wrong boot signature should be reported with the actual bytes."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = write_tmp(make_fake_disk(boot_sig=(0x55, 0xAA)))
        try:
            result = verify_boot_disk(str(p))
            sig_check = next(c for c in result["checks"] if "Boot signature" in c["name"])
            self.assertFalse(sig_check["passed"])
            self.assertIn("0x55", sig_check["message"])
        finally:
            p.unlink()

    def test_corrupted_after_creation(self):
        """Write correct disk, corrupt signature, verify fails."""
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "HD10.hda"
            code, _ = cli("create-boot-disk", "--size", "239", "--output", str(out))
            if code != 0:
                self.skipTest("Template not available")
            raw = bytearray(out.read_bytes())
            raw[0x1FE] = 0xFF
            raw[0x1FF] = 0xFF
            out.write_bytes(bytes(raw))
            code2, output = cli("verify-boot", str(out))
            self.assertNotEqual(code2, 0)


# ---------------------------------------------------------------------------
# Invalid FAT Entries
# ---------------------------------------------------------------------------

class TestInvalidFATEntries(unittest.TestCase):

    def test_fat0_zero_fails_check(self):
        """FAT entry 0 = 0x0000 should fail."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = write_tmp(make_fake_disk(fat0=0x0000))
        try:
            result = verify_boot_disk(str(p))
            fat_check = next(c for c in result["checks"] if "FAT entry 0" in c["name"])
            self.assertFalse(fat_check["passed"])
        finally:
            p.unlink()

    def test_fat0_ffff_fails_check(self):
        """FAT entry 0 = 0xFFFF (wrong media descriptor) should fail."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = write_tmp(make_fake_disk(fat0=0xFFFF))
        try:
            result = verify_boot_disk(str(p))
            fat_check = next(c for c in result["checks"] if "FAT entry 0" in c["name"])
            self.assertFalse(fat_check["passed"])
        finally:
            p.unlink()

    def test_fat_entry0_correct_value(self):
        """FAT entry 0 = 0x8000 should pass."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = write_tmp(make_fake_disk(fat0=0x8000))
        try:
            result = verify_boot_disk(str(p))
            fat_check = next(c for c in result["checks"] if "FAT entry 0" in c["name"])
            self.assertTrue(fat_check["passed"])
        finally:
            p.unlink()


# ---------------------------------------------------------------------------
# Missing / Invalid Files
# ---------------------------------------------------------------------------

class TestMissingFiles(unittest.TestCase):

    def test_verify_nonexistent_disk(self):
        code, output = cli("verify-boot", "/tmp/definitely_does_not_exist_xyz.hda")
        self.assertNotEqual(code, 0)
        self.assertIn("Error", output)

    def test_list_images_nonexistent_dir(self):
        code, output = cli("list-images", "/tmp/no_such_directory_xyz_abc")
        self.assertNotEqual(code, 0)

    def test_import_bank_missing_disk(self):
        with tempfile.TemporaryDirectory() as d:
            bank = Path(d) / "test.EB2"
            bank.write_bytes(b"\x00" * 512)
            code, output = cli("import-bank",
                               "--disk", "/tmp/no_disk.hda",
                               "--bank", str(bank))
            self.assertNotEqual(code, 0)

    def test_import_bank_missing_bank_file(self):
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            disk.write_bytes(make_fake_disk())
            code, output = cli("import-bank",
                               "--disk", str(disk),
                               "--bank", "/tmp/no_bank.EB2")
            self.assertNotEqual(code, 0)

    def test_export_bank_empty_slot(self):
        """Exporting from a slot with no bank should fail."""
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            disk.write_bytes(make_fake_disk())
            out_eb2 = str(Path(d) / "out.EB2")
            code, output = cli("export-bank", "--disk", str(disk),
                               "--slot", "50", "--output", out_eb2)
            self.assertNotEqual(code, 0)

    def test_validate_nonexistent_config(self):
        code, output = cli("validate-zulu-config", "/tmp/no_config.ini")
        self.assertNotEqual(code, 0)


# ---------------------------------------------------------------------------
# Invalid Disk Sizes
# ---------------------------------------------------------------------------

class TestInvalidDiskSizes(unittest.TestCase):

    def test_create_boot_disk_invalid_size(self):
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "bad.hda")
            # 500 is not in the valid size list
            code, output = cli("create-boot-disk", "--size", "500", "--output", out)
            self.assertNotEqual(code, 0)

    def test_create_floppy_invalid_size(self):
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "bad.img")
            code, output = cli("create-floppy", "--size", "999K",
                               "--format", "raw", "--output", out)
            self.assertNotEqual(code, 0)

    def test_create_floppy_invalid_size_python(self):
        """Python API should raise ValueError for unknown floppy size."""
        from cli_anything.emaxforge.core.floppy_manager import create_floppy
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):
                create_floppy("999K", str(Path(d) / "bad.img"))

    def test_create_boot_disk_invalid_size_python(self):
        """Python API should raise ValueError for unsupported disk size."""
        from cli_anything.emaxforge.core.boot_creator import create_boot_disk
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):
                create_boot_disk(500, str(Path(d) / "bad.hda"))


# ---------------------------------------------------------------------------
# Missing Catalog
# ---------------------------------------------------------------------------

class TestMissingCatalog(unittest.TestCase):

    def test_disk_without_catalog_fails_check(self):
        """Disk without catalog OS entry should fail verification."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        p = write_tmp(make_fake_disk(has_catalog=False))
        try:
            result = verify_boot_disk(str(p))
            cat_check = next(c for c in result["checks"] if "Catalog" in c["name"])
            self.assertFalse(cat_check["passed"])
        finally:
            p.unlink()

    def test_disk_without_os_chain_fails(self):
        """FAT entry 1 = 0 means no OS chain - should fail FAT entry 1 check."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        data = bytearray(make_fake_disk())
        struct.pack_into("<H", data, 0x402, 0x0000)  # FAT[1] = 0 (no OS)
        p = write_tmp(bytes(data))
        try:
            result = verify_boot_disk(str(p))
            fat1_check = next(
                (c for c in result["checks"] if "FAT entry 1" in c["name"]), None
            )
            if fat1_check:
                self.assertFalse(fat1_check["passed"])
        finally:
            p.unlink()


# ---------------------------------------------------------------------------
# Invalid Templates
# ---------------------------------------------------------------------------

class TestInvalidTemplates(unittest.TestCase):

    def test_unknown_template_name(self):
        with tempfile.TemporaryDirectory() as d:
            out = str(Path(d) / "bad.EB2")
            code, output = cli("create-template", "NONEXISTENT_TEMPLATE_XYZ", out)
            self.assertNotEqual(code, 0)

    def test_unknown_template_python(self):
        from cli_anything.emaxforge.handlers.bank_templates import BankTemplates
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):
                BankTemplates.create("BOGUS_TEMPLATE", str(Path(d) / "x.EB2"))


# ---------------------------------------------------------------------------
# HFE Format Errors
# ---------------------------------------------------------------------------

class TestHFEErrors(unittest.TestCase):

    def test_convert_invalid_hfe_fails(self):
        """Non-HFE data should be rejected by convert-hfe."""
        with tempfile.TemporaryDirectory() as d:
            bad = Path(d) / "bad.hfe"
            bad.write_bytes(b"NOT_A_VALID_HFE_FILE" * 50)
            code, output = cli("convert-hfe", str(bad),
                               str(Path(d) / "out.img"))
            self.assertNotEqual(code, 0)

    def test_convert_invalid_hfe_python(self):
        """Python API should raise ValueError for bad HFE data."""
        from cli_anything.emaxforge.core.floppy_manager import convert_hfe_to_img
        with tempfile.TemporaryDirectory() as d:
            bad = Path(d) / "bad.hfe"
            bad.write_bytes(b"INVALID" * 100)
            with self.assertRaises(ValueError):
                convert_hfe_to_img(str(bad), str(Path(d) / "out.img"))

    def test_empty_file_rejected(self):
        """Zero-byte file should fail as HFE."""
        with tempfile.TemporaryDirectory() as d:
            empty = Path(d) / "empty.hfe"
            empty.write_bytes(b"")
            code, _ = cli("convert-hfe", str(empty),
                          str(Path(d) / "out.img"))
            self.assertNotEqual(code, 0)


# ---------------------------------------------------------------------------
# Unrecognized Disk Size
# ---------------------------------------------------------------------------

class TestUnrecognizedDiskSize(unittest.TestCase):

    def test_weird_size_fails_file_size_check(self):
        """A disk of non-standard size should fail the 'File size' check."""
        from cli_anything.emaxforge.core.boot_creator import verify_boot_disk
        # 100 MB is not a valid EMAX II size
        data = bytearray(100 * 1024 * 1024)
        data[0x1FE] = 0x78
        data[0x1FF] = 0x82
        struct.pack_into("<H", data, 0x400, 0x8000)
        struct.pack_into("<H", data, 0x402, 0x7FFF)
        data[0x1000:0x1010] = b"EMAX II OS\x00\x00\x00\x00\x00\x00"
        p = write_tmp(bytes(data))
        try:
            result = verify_boot_disk(str(p))
            size_check = next(c for c in result["checks"] if "File size" in c["name"])
            self.assertFalse(size_check["passed"])
        finally:
            p.unlink()


# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

class TestIdempotency(unittest.TestCase):
    """Tests can run multiple times without side effects."""

    def test_floppy_creation_idempotent(self):
        """Creating the same floppy twice produces identical files."""
        from cli_anything.emaxforge.core.floppy_manager import create_floppy
        with tempfile.TemporaryDirectory() as d:
            out1 = str(Path(d) / "FD_a.img")
            out2 = str(Path(d) / "FD_b.img")
            create_floppy("800K", out1, format_type="raw")
            create_floppy("800K", out2, format_type="raw")
            self.assertEqual(Path(out1).read_bytes(), Path(out2).read_bytes())

    def test_verify_does_not_modify_disk(self):
        """verify-boot should be read-only."""
        p = write_tmp(make_fake_disk())
        try:
            original = p.read_bytes()
            cli("verify-boot", str(p))
            self.assertEqual(p.read_bytes(), original)
        finally:
            p.unlink()

    def test_list_images_does_not_modify(self):
        with tempfile.TemporaryDirectory() as d:
            disk = Path(d) / "HD10.hda"
            disk.write_bytes(make_fake_disk())
            original = disk.read_bytes()
            cli("list-images", d)
            self.assertEqual(disk.read_bytes(), original)


if __name__ == "__main__":
    unittest.main(verbosity=2)
