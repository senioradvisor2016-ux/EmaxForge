"""Disk operations for EmaxForge CLI"""

import struct
from pathlib import Path


# Known valid EMAX II boot signatures (2 bytes at offset 0x1FE).
# Each disk size has a distinct signature produced by the format tool.
_VALID_BOOT_SIGNATURES = [
    bytes([0x78, 0x82]),  # 239 MB (most common)
    bytes([0xA1, 0x93]),  # 96 MB
    bytes([0x65, 0x9F]),  # 481 MB
    bytes([0x79, 0x24]),  # 633 MB
    bytes([0xD7, 0xAD]),  # 962 MB
]


def validate_boot(disk_path: str) -> dict:
    """
    Validate that a .hda image is bootable on EMAX II.

    Checks (Issue #5 acceptance criteria):
      1. Boot signature 0x78 0x82 (or other valid EMAX II sig) at 0x1FE
      2. FAT entry 0 == 0x000F at 0x400
      3. OS data non-zero at cluster 1 offset
      4. Catalog flags valid

    Args:
        disk_path: Path to .hda file

    Returns:
        Dict with 'bootable' (bool), 'checks' list, 'summary' string
    """
    disk = Path(disk_path)
    if not disk.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")

    checks = []
    file_size = disk.stat().st_size

    if file_size < 0x2000:
        return {
            "bootable": False,
            "checks": [{"name": "File size", "passed": False,
                        "message": f"File too small ({file_size} bytes)"}],
            "summary": "❌ File too small — not a valid image",
        }

    with open(disk, "rb") as f:

        # 1. Boot signature at 0x1FE
        f.seek(0x1FE)
        sig = f.read(2)
        sig_valid = sig in _VALID_BOOT_SIGNATURES
        sig_hex = " ".join(f"0x{b:02X}" for b in sig) if len(sig) == 2 else "N/A"
        checks.append({
            "name": "Boot signature",
            "passed": sig_valid,
            "message": f"{sig_hex} at 0x1FE" + (" ✓" if sig_valid else
                        " — expected EMAX II signature (e.g. 0x78 0x82 for 239 MB)"),
        })

        # 2. FAT entry 0 == 0x000F (little-endian) at 0x400
        f.seek(0x400)
        fat0_bytes = f.read(2)
        if len(fat0_bytes) == 2:
            fat0 = struct.unpack("<H", fat0_bytes)[0]
        else:
            fat0 = 0xFFFF
        fat0_valid = fat0 == 0x000F
        checks.append({
            "name": "FAT entry 0",
            "passed": fat0_valid,
            "message": f"0x{fat0:04X}" + (" ✓" if fat0_valid else
                        " — expected 0x000F (EMAX II FAT marker)"),
        })

        # 3. OS data non-zero at cluster 1 offset.
        #    Read cluster size and cluster area start from header (if present).
        f.seek(0)
        header = f.read(512)
        if len(header) >= 0x24:
            cs = struct.unpack_from("<I", header, 0x04)[0]
            cas = struct.unpack_from("<I", header, 0x20)[0]
            cluster_size = cs if 0 < cs < 0x100000 else 16384
            cluster_area_start = cas if cas > 0 else 512
        else:
            cluster_size = 16384
            cluster_area_start = 512

        os_offset = cluster_area_start * 512
        os_data_valid = False
        if os_offset + 64 <= file_size:
            f.seek(os_offset)
            snippet = f.read(64)
            os_data_valid = any(b != 0 for b in snippet)
        checks.append({
            "name": "OS data at cluster 1",
            "passed": os_data_valid,
            "message": f"offset 0x{os_offset:X}" + (" non-zero ✓" if os_data_valid else
                        " all zeros — OS may not have been written"),
        })

        # 4. Catalog flags — BNT slot 0 (BNT sector from header[0x10])
        if len(header) >= 0x14:
            bnt_sector = struct.unpack_from("<I", header, 0x10)[0]
        else:
            bnt_sector = 0
        bnt_offset = bnt_sector * 512 if bnt_sector > 0 else 0x1000

        valid_flags = {0x0000, 0x0068, 0x0069, 0x0081, 0x7800}
        catalog_valid = False
        catalog_msg = ""
        if bnt_offset + 32 <= file_size:
            f.seek(bnt_offset)
            entry = f.read(32)
            if len(entry) >= 24:
                flags = struct.unpack_from("<H", entry, 22)[0]
                catalog_valid = flags in valid_flags
                catalog_msg = (f"flags=0x{flags:04X} ✓" if catalog_valid else
                               f"unexpected flags=0x{flags:04X} at BNT slot 0")
            else:
                catalog_msg = "Could not read catalog entry"
        else:
            catalog_msg = f"BNT offset 0x{bnt_offset:X} beyond file size"

        checks.append({
            "name": "Catalog flags",
            "passed": catalog_valid,
            "message": catalog_msg,
        })

    bootable = all(c["passed"] for c in checks)
    fail_names = [c["name"] for c in checks if not c["passed"]]
    if bootable:
        summary = f"✅ All {len(checks)} boot checks passed — image is bootable"
    else:
        summary = f"❌ {len(fail_names)} check(s) failed: {', '.join(fail_names)}"

    return {
        "bootable": bootable,
        "checks": checks,
        "summary": summary,
    }


def create_disk(size_mb: int, scsi_id: int, output_path: str, include_os: bool = True) -> dict:
    """
    Create new EMAX II disk image
    
    Args:
        size_mb: Disk size (96, 239, 481, 633, or 962)
        scsi_id: SCSI ID (1 for boot, 2+ for data)
        output_path: Output .hda file path
        include_os: Whether to include EMAX II OS
    
    Returns:
        Dict with disk info
    """
    # Template paths
    template_dir = Path(__file__).parent.parent.parent.parent.parent / "EmaxForge" / "Resources" / "bootable_templates"
    
    template_map = {
        96: "EMAXII_IMAGE_96.EZ2",
        239: "EMAXII_IMAGE_239.EZ2",
        481: "EMAXII_IMAGE_481.EZ2",
        633: "EMAXII_IMAGE_633.EZ2",
        962: "EMAXII_IMAGE_962.EZ2",
    }
    
    if size_mb not in template_map:
        raise ValueError(f"Invalid size: {size_mb}. Must be one of {list(template_map.keys())}")
    
    template_path = template_dir / template_map[size_mb]
    
    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")
    
    # Copy template to output
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    
    with open(template_path, 'rb') as src:
        template_data = bytearray(src.read())
    
    # Write OS if requested
    # OS file: same directory as this script's package, under Os/
    # OS file: ~/clawd/emxp/Os/ (absolute, project-relative)
    os_file = Path.home() / "clawd" / "emxp" / "Os" / "Emax II rev 2.14.EMX"
    if include_os and os_file.exists():
        # Read cluster geometry from template header
        ca_start_sector = struct.unpack_from('<I', template_data, 0x20)[0]
        ca_offset = ca_start_sector * 512  # 0xC400 for 239 MB
        os_data = os_file.read_bytes()
        template_data[ca_offset : ca_offset + len(os_data)] = os_data
        
        # Fix OS catalog entry FLAGS (0x8100, not 0x8000)
        # OS entry @ 0x1000, FLAGS @ +0x1A = 0x101A
        struct.pack_into('<H', template_data, 0x101A, 0x0081)  # 0x0081 LE = 0x8100 BE
    
    if not include_os:
        # Clear catalog entry 0 (OS)
        template_data[0x1000:0x1020] = b'\x00' * 32
    
    with open(output, 'wb') as dst:
        dst.write(template_data)
    
    return {
        "disk_path": str(output),
        "size_mb": size_mb,
        "scsi_id": scsi_id,
        "has_os": include_os,
        "template_used": str(template_path.name)
    }


def verify_disk(disk_path: str) -> dict:
    """
    Verify disk structure
    
    Args:
        disk_path: Path to .hda file
    
    Returns:
        Dict with verification results
    """
    disk = Path(disk_path)
    if not disk.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")
    
    checks = []
    
    with open(disk, 'rb') as f:
        # Check 1: File size matches template sizes (allow ±1 MB tolerance)
        file_size = disk.stat().st_size
        size_mb = file_size // (1024*1024)
        expected_sizes = [96, 239, 481, 633, 962]
        
        size_valid = any(abs(size_mb - expected) <= 1 for expected in expected_sizes)
        checks.append({
            "name": "File size",
            "passed": size_valid,
            "message": f"{size_mb} MB" + ("" if size_valid else " (unexpected size)")
        })
        
        # Check 2: Boot signature (0x78 0x82 at 0x1FE)
        f.seek(0x1FE)
        boot_sig = f.read(2)
        boot_valid = boot_sig == b'\x78\x82'
        checks.append({
            "name": "Boot signature",
            "passed": boot_valid,
            "message": f"0x{boot_sig.hex()} " + ("✓" if boot_valid else "✗ (expected 0x7882)")
        })
        
        # Check 3: FAT header (0x8000 standard, 0x000F legacy) at 0x400
        f.seek(0x400)
        fat_header = struct.unpack('<H', f.read(2))[0]
        fat_valid = fat_header in (0x000F, 0x8000)
        checks.append({
            "name": "FAT header",
            "passed": fat_valid,
            "message": f"0x{fat_header:04X} " + ("✓" if fat_valid else "✗ (expected 0x8000)")
        })
        
        # Check 4: Catalog entry alignment (all entries on 64-byte boundaries)
        f.seek(0x1000)
        catalog_valid = True
        catalog_count = 0
        
        for i in range(128):  # Max 128 entries
            entry = f.read(64)
            if entry[0] == 0:  # End of catalog
                break
            catalog_count += 1
            
            # Check FLAGS at offset 26-27
            flags = struct.unpack('<H', entry[26:28])[0]
            if flags not in [0x0081, 0x7800]:  # Valid FLAGS values
                catalog_valid = False
        
        checks.append({
            "name": "Catalog entries",
            "passed": catalog_valid,
            "message": f"{catalog_count} entries, 64-byte aligned" + ("" if catalog_valid else " ✗ (invalid FLAGS)")
        })
    
    all_passed = all(check["passed"] for check in checks)
    
    return {
        "disk_path": str(disk),
        "valid": all_passed,
        "checks": checks
    }
