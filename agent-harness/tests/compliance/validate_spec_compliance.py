"""
EMAX II spec compliance validator.

Verifies that disk images created by EmaxForge match the exact byte-level
requirements of the EMAX II disk format specification.

Usage:
    python validate_spec_compliance.py [--json]
    python -m pytest validate_spec_compliance.py -v
"""

import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HARNESS_DIR = Path(__file__).parents[2]

# ---------------------------------------------------------------------------
# Spec constants
# ---------------------------------------------------------------------------

# Per-size boot signatures at offset 0x1FE
BOOT_SIG_SPEC: dict[int, tuple[int, int]] = {
    96:  (0xA1, 0x93),
    239: (0x78, 0x82),
    481: (0x65, 0x9F),
    633: (0x79, 0x24),
    962: (0xD7, 0xAD),
}

# Actual template sizes (SCSI geometry — NOT exact MiB multiples)
# Measured from the real EZ2 template files.
DISK_SIZE_SPEC: dict[int, int] = {
    96:  100_528_128,
    239: 250_398_720,
    481: 503_900_160,
    633: 663_302_144,
    962: 1_007_765_504,
}

# FAT structure
FAT_OFFSET          = 0x400   # 1024
FAT_ENTRY0_EXPECTED = 0x8000  # Media descriptor
FAT_ENTRY1_MIN      = 0x0001  # OS chain must be non-zero

# Catalog
CATALOG_OFFSET     = 0x1000   # 4096
CATALOG_ENTRY_SIZE = 0x40     # 64 bytes

# Boot signature offset
BOOT_SIG_OFFSET = 0x1FE


# ---------------------------------------------------------------------------
# Compliance check functions
# ---------------------------------------------------------------------------

def check_boot_signature(data: bytes, size_mb: int) -> dict:
    expected_b0, expected_b1 = BOOT_SIG_SPEC[size_mb]
    actual_b0 = data[BOOT_SIG_OFFSET]
    actual_b1 = data[BOOT_SIG_OFFSET + 1]
    passed = actual_b0 == expected_b0 and actual_b1 == expected_b1
    return {
        "check": "boot_signature",
        "passed": passed,
        "expected": f"0x{expected_b0:02X} 0x{expected_b1:02X}",
        "actual":   f"0x{actual_b0:02X} 0x{actual_b1:02X}",
        "message":  "OK" if passed else f"Expected {expected_b0:02X} {expected_b1:02X}, got {actual_b0:02X} {actual_b1:02X}",
    }


def check_file_size(data: bytes, size_mb: int) -> dict:
    expected = DISK_SIZE_SPEC[size_mb]
    actual = len(data)
    passed = actual == expected
    return {
        "check": "file_size",
        "passed": passed,
        "expected": expected,
        "actual":   actual,
        "message":  "OK" if passed else f"Expected {expected} bytes ({size_mb} MB), got {actual}",
    }


def check_fat_entry0(data: bytes) -> dict:
    if len(data) < FAT_OFFSET + 2:
        return {"check": "fat_entry_0", "passed": False,
                "message": "File too small to read FAT"}
    entry0 = struct.unpack_from("<H", data, FAT_OFFSET)[0]
    passed = entry0 == FAT_ENTRY0_EXPECTED
    return {
        "check": "fat_entry_0",
        "passed": passed,
        "expected": f"0x{FAT_ENTRY0_EXPECTED:04X}",
        "actual":   f"0x{entry0:04X}",
        "message":  "OK" if passed else f"Expected 0x{FAT_ENTRY0_EXPECTED:04X}, got 0x{entry0:04X}",
    }


def check_fat_entry1_nonzero(data: bytes) -> dict:
    if len(data) < FAT_OFFSET + 4:
        return {"check": "fat_entry_1", "passed": False,
                "message": "File too small to read FAT[1]"}
    entry1 = struct.unpack_from("<H", data, FAT_OFFSET + 2)[0]
    passed = entry1 >= FAT_ENTRY1_MIN
    return {
        "check": "fat_entry_1_nonzero",
        "passed": passed,
        "expected": f">= 0x{FAT_ENTRY1_MIN:04X}",
        "actual":   f"0x{entry1:04X}",
        "message":  "OS chain present" if passed else "No OS chain (FAT[1] = 0)",
    }


def check_catalog_os_entry(data: bytes) -> dict:
    if len(data) < CATALOG_OFFSET + 16:
        return {"check": "catalog_os_entry", "passed": False,
                "message": "File too small to read catalog"}
    name_bytes = data[CATALOG_OFFSET: CATALOG_OFFSET + 16].rstrip(b"\x00")
    passed = len(name_bytes) > 0
    name_str = name_bytes.decode("latin-1", errors="replace") if name_bytes else "(empty)"
    return {
        "check": "catalog_os_entry",
        "passed": passed,
        "expected": "non-empty name",
        "actual":   name_str,
        "message":  f"OS entry: {name_str!r}" if passed else "No OS catalog entry",
    }


def validate_image(path: Path, size_mb: int) -> dict:
    """Run all compliance checks against a disk image."""
    if not path.exists():
        return {
            "path": str(path),
            "size_mb": size_mb,
            "passed": False,
            "error": "File not found",
            "checks": [],
        }

    data = path.read_bytes()

    checks = [
        check_file_size(data, size_mb),
        check_boot_signature(data, size_mb),
        check_fat_entry0(data),
        check_fat_entry1_nonzero(data),
        check_catalog_os_entry(data),
    ]

    all_passed = all(c["passed"] for c in checks)

    return {
        "path": str(path),
        "size_mb": size_mb,
        "passed": all_passed,
        "checks": checks,
        "pass_count":  sum(1 for c in checks if c["passed"]),
        "total_checks": len(checks),
    }


# ---------------------------------------------------------------------------
# Standalone runner (non-pytest)
# ---------------------------------------------------------------------------

def has_space_for(size_mb: int) -> bool:
    import shutil
    free = shutil.disk_usage(tempfile.gettempdir()).free
    return free >= (size_mb + 100) * 1024 * 1024


def run_compliance_suite(output_json: bool = False) -> dict:
    """Create one disk per size and validate each."""
    results = []
    total_checks = 0
    passed_checks = 0

    with tempfile.TemporaryDirectory() as d:
        dp = Path(d)
        for size_mb in sorted(BOOT_SIG_SPEC.keys()):
            if not has_space_for(size_mb):
                results.append({
                    "size_mb": size_mb,
                    "passed": False,
                    "error": "Skipped: insufficient /tmp space",
                    "checks": [],
                    "pass_count": 0, "total_checks": 0,
                })
                continue
            out = dp / f"HD10_{size_mb}mb.hda"
            proc = subprocess.run(
                [sys.executable, "-m", "cli_anything.emaxforge",
                 "create-boot-disk", "--size", str(size_mb),
                 "--output", str(out)],
                capture_output=True, text=True,
                cwd=str(HARNESS_DIR),
            )

            if proc.returncode != 0:
                results.append({
                    "size_mb": size_mb,
                    "passed": False,
                    "error": f"create-boot-disk failed: {proc.stderr.strip()}",
                    "checks": [],
                })
                continue

            result = validate_image(out, size_mb)
            results.append(result)
            total_checks += result["total_checks"]
            passed_checks += result["pass_count"]

    compliance_pct = (passed_checks / total_checks * 100) if total_checks else 0.0
    summary = {
        "compliance_percent": round(compliance_pct, 1),
        "passed_checks": passed_checks,
        "total_checks": total_checks,
        "sizes_tested": len(results),
        "all_passed": all(r["passed"] for r in results),
        "results": results,
    }

    if output_json:
        print(json.dumps(summary, indent=2))
    else:
        print(f"\n{'=' * 50}")
        print(f"  EMAX II Spec Compliance Report")
        print(f"{'=' * 50}")
        for r in results:
            status = "PASS" if r["passed"] else "FAIL"
            err = r.get("error", "")
            print(f"\n  [{status}] {r['size_mb']} MB  {err}")
            for c in r.get("checks", []):
                icon = "  ✓" if c["passed"] else "  ✗"
                print(f"    {icon} {c['check']}: {c['message']}")

        print(f"\n{'=' * 50}")
        print(f"  Compliance: {compliance_pct:.1f}%  "
              f"({passed_checks}/{total_checks} checks passed)")
        print(f"{'=' * 50}\n")

    return summary


# ---------------------------------------------------------------------------
# pytest test class
# ---------------------------------------------------------------------------

def _cli(*args) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.emaxforge", *args],
        capture_output=True, text=True,
        cwd=str(HARNESS_DIR),
    )
    return result.returncode, result.stdout + result.stderr


class TestSpecCompliance(unittest.TestCase):
    """Validate each disk size against the EMAX II spec."""

    def _validate_size(self, size_mb: int):
        if not has_space_for(size_mb):
            self.skipTest(f"Insufficient /tmp space for {size_mb} MB disk")
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / f"HD10_{size_mb}mb.hda"
            code, output = _cli("create-boot-disk", "--size", str(size_mb),
                                 "--output", str(out))
            if code != 0:
                self.skipTest(f"Template for {size_mb} MB not available")
            result = validate_image(out, size_mb)

            failed = [c for c in result["checks"] if not c["passed"]]
            self.assertTrue(result["passed"],
                f"{size_mb} MB failed {len(failed)} checks:\n" +
                "\n".join(f"  {c['check']}: {c['message']}" for c in failed))

    def test_compliance_96mb(self):
        self._validate_size(96)

    def test_compliance_239mb(self):
        self._validate_size(239)

    def test_compliance_481mb(self):
        self._validate_size(481)

    def test_compliance_633mb(self):
        if not has_space_for(633):
            self.skipTest("Insufficient /tmp space")
        self._validate_size(633)

    def test_compliance_962mb(self):
        if not has_space_for(962):
            self.skipTest("Insufficient /tmp space")
        self._validate_size(962)

    def test_boot_signatures_are_unique(self):
        """Each size must have a distinct boot signature."""
        sigs = list(BOOT_SIG_SPEC.values())
        self.assertEqual(len(sigs), len(set(sigs)),
                         "Duplicate boot signatures in spec!")

    def test_fat_entry0_constant(self):
        """FAT entry 0 = 0x8000 (EMXP standard) is the same across all disk sizes."""
        for size_mb in BOOT_SIG_SPEC:
            with tempfile.TemporaryDirectory() as d:
                out = Path(d) / f"disk_{size_mb}.hda"
                code, _ = _cli("create-boot-disk", "--size", str(size_mb),
                                "--output", str(out))
                if code != 0:
                    continue
                data = out.read_bytes()
                entry0 = struct.unpack_from("<H", data, FAT_OFFSET)[0]
                self.assertEqual(entry0, 0x8000,
                    f"{size_mb} MB: FAT[0]=0x{entry0:04X}, expected 0x8000")

    def test_catalog_os_entry_present(self):
        """Every boot disk template must have a non-empty OS catalog entry."""
        for size_mb in BOOT_SIG_SPEC:
            with tempfile.TemporaryDirectory() as d:
                out = Path(d) / f"disk_{size_mb}.hda"
                code, _ = _cli("create-boot-disk", "--size", str(size_mb),
                                "--output", str(out))
                if code != 0:
                    continue
                data = out.read_bytes()
                result = check_catalog_os_entry(data)
                self.assertTrue(result["passed"],
                    f"{size_mb} MB: {result['message']}")

    def test_disk_sizes_match_spec(self):
        """Every created disk must be exactly the right number of bytes."""
        for size_mb in BOOT_SIG_SPEC:
            with tempfile.TemporaryDirectory() as d:
                out = Path(d) / f"disk_{size_mb}.hda"
                code, _ = _cli("create-boot-disk", "--size", str(size_mb),
                                "--output", str(out))
                if code != 0:
                    continue
                actual_bytes = out.stat().st_size
                expected_bytes = DISK_SIZE_SPEC[size_mb]
                self.assertEqual(actual_bytes, expected_bytes,
                    f"{size_mb} MB: expected {expected_bytes} bytes, "
                    f"got {actual_bytes}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="EMAX II spec compliance validator")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--pytest", action="store_true", help="Run as pytest")
    args = parser.parse_args()

    if args.pytest:
        import pytest
        sys.exit(pytest.main([__file__, "-v"]))
    else:
        summary = run_compliance_suite(output_json=args.json)
        sys.exit(0 if summary["all_passed"] else 1)
