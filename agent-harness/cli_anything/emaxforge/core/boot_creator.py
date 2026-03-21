"""Boot disk creation operations for EmaxForge CLI-Anything harness"""

import shutil
from pathlib import Path


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

VALID_SIZES = [96, 239, 481, 633, 962]

# Map MB → EZ2 template filename
TEMPLATE_MAP = {
    96:  "EMAXII_IMAGE_96.EZ2",
    239: "EMAXII_IMAGE_239.EZ2",
    481: "EMAXII_IMAGE_481.EZ2",
    633: "EMAXII_IMAGE_633.EZ2",
    962: "EMAXII_IMAGE_962.EZ2",
}

# Offsets within EMAX II disk image
BOOT_SIG_OFFSET    = 0x1FE       # 510
BOOT_SIG_BYTES     = (0x78, 0x82)  # 239MB default
# Boot signatures vary by disk size (EMXP verified)
BOOT_SIGS_BY_SIZE = {
    96:  (0xA1, 0x93),
    239: (0x78, 0x82),
    481: (0x65, 0x9F),
    633: (0x79, 0x24),
    962: (0xD7, 0xAD),
}
VALID_BOOT_SIGS = set(BOOT_SIGS_BY_SIZE.values())
FAT_OFFSET         = 0x400       # 1024
CATALOG_OFFSET     = 0x1000      # 4096
CATALOG_ENTRY_SIZE = 0x40        # 64 bytes
OS_VERSION_OFFSET  = 0x20        # within header (32 bytes in)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def create_boot_disk(size_mb: int, output_path: str, os_version: str = "2.14",
                     scsi_id: int = 1) -> dict:
    """
    Create an EMAX II boot disk image from the built-in templates.
    Writes OS data to cluster 1 (template only has structure, no OS bytes).

    Args:
        size_mb:     Disk size in MB (96, 239, 481, 633, or 962)
        output_path: Destination .hda file path
        os_version:  EMAX II OS version string (embedded in header)
        scsi_id:     ZuluSCSI SCSI ID (1 = primary boot)

    Returns:
        Dict with boot disk info
    """
    import struct

    if size_mb not in VALID_SIZES:
        raise ValueError(f"Invalid size {size_mb} MB. Valid: {VALID_SIZES}")

    template_path = _find_template(size_mb)

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    # Copy template
    shutil.copy2(template_path, output)

    # Post-template fixes: status byte, OS entry flags, OS data
    os_bin = _find_os_bin()
    with open(output, 'r+b') as f:
        # Read header geometry
        f.seek(0)
        hdr = f.read(512)
        bnt_start_sec   = struct.unpack_from('<I', hdr, 0x10)[0]
        ca_start_sector = struct.unpack_from('<I', hdr, 0x20)[0]
        total_clusters  = struct.unpack_from('<I', hdr, 0x24)[0]
        ca_offset       = ca_start_sector * 512

        # Compute cluster size from geometry (not from header field 0x04 which is wrong)
        disk_size_sectors = output.stat().st_size // 512
        sects_per_cluster = (disk_size_sectors - ca_start_sector) // total_clusters
        cluster_size      = sects_per_cluster * 512

        # 1. FAT[0] at 0x200: 0x09 = bootable empty (EMXP standard for new boot disk)
        #    0x0F = boot disk with banks added later
        f.seek(0x200)
        f.write(b'\x09')

        # 2. Clear BNT area (template has 0x42 fill = garbage entries)
        # Preserve slot 0 (OS entry, 32 bytes), zero rest
        bnt_offset = bnt_start_sec * 512
        ca_offset_for_bnt = ca_start_sector * 512
        bnt_size = ca_offset_for_bnt - bnt_offset
        f.seek(bnt_offset)
        slot0 = bytearray(f.read(32))
        # Fix slot 0 flags: 0x0081 (active)
        struct.pack_into('<H', slot0, 26, 0x0081)
        # Write clean BNT: slot 0 + zeros
        f.seek(bnt_offset)
        f.write(bytes(slot0))
        f.write(b'\x00' * (bnt_size - 32))

        # 3. Write OS data to correct cluster (from BNT slot 0 startCluster field)
        #    and mark all OS clusters in FAT as used.
        #
        # BUG HISTORY: os was wrongly written to ca_offset (cluster 0 area base),
        # but BNT slot 0 says startCluster=0x7800 (cluster idx 240 for 96 MB disks).
        # Bank allocator then assigned cluster 240 to sample banks → overwrites OS!
        #
        # FIX: Read startCluster from BNT slot 0, compute correct byte offset,
        #      write OS there, and mark those clusters as USED in FAT.
        # Read OS location from BNT slot 0
        f.seek(bnt_offset)
        slot0_raw = bytearray(f.read(32))
        os_start_cluster = struct.unpack_from('<H', slot0_raw, 18)[0]  # BNT +18 = startCluster (1-based)
        os_cluster_count = struct.unpack_from('<H', slot0_raw, 20)[0]  # BNT +20 = clusterCount

        # Convert 1-based cluster index to byte offset
        os_cluster_idx     = os_start_cluster  # already 1-based (cluster 1 = OS)
        os_byte_offset     = ca_offset + (os_cluster_idx - 1) * cluster_size

        # How many clusters does the OS span?
        os_clusters_needed = os_cluster_count if os_cluster_count > 0 else 1

        if os_bin:
            os_data = os_bin.read_bytes()
            f.seek(os_byte_offset)
            write_data = os_data
            if len(write_data) < os_clusters_needed * cluster_size:
                write_data = write_data + b'\x00' * (os_clusters_needed * cluster_size - len(write_data))
            f.write(write_data)
            os_written = True
        else:
            os_written = False

        # CRITICAL: Mark OS clusters in FAT as USED so bank allocator skips them.
        # Without this, banks get assigned to OS clusters → OS overwritten → "disk not formatted"!
        f.seek(0x400)
        fat_bytes = bytearray(f.read(total_clusters * 2 + 4))
        for i in range(os_clusters_needed):
            cl = os_cluster_idx + i
            if cl < total_clusters:
                next_val = (os_cluster_idx + i + 1) if i < os_clusters_needed - 1 else 0x7FFF
                struct.pack_into('<H', fat_bytes, cl * 2, next_val)
        f.seek(0x400)
        f.write(fat_bytes)

    # Verify boot signature
    data = bytearray(output.read_bytes())
    actual_sig = (data[BOOT_SIG_OFFSET], data[BOOT_SIG_OFFSET + 1])
    boot_ok = actual_sig in VALID_BOOT_SIGS

    return {
        "path": str(output),
        "size_mb": size_mb,
        "size_bytes": len(data),
        "scsi_id": scsi_id,
        "os_version": os_version,
        "boot_signature_valid": boot_ok,
        "os_written": os_written,
        "template": template_path.name,
        "zuluscsi_name": _zuluscsi_name(scsi_id),
    }


def verify_boot_disk(disk_path: str) -> dict:
    """
    Perform structural verification of a boot disk image.

    Checks:
      - Boot signature (0x78 0x82 at 0x1FE)
      - FAT entry 0 (0x8000 EMXP standard)
      - FAT entry 1 (OS chain)
      - Catalog OS entry present
      - File size matches a known disk size

    Returns:
        Dict with verification result and individual check outcomes
    """
    p = Path(disk_path)
    if not p.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")

    data = p.read_bytes()
    checks = []

    # 1. Boot signature
    actual_sig = (data[BOOT_SIG_OFFSET], data[BOOT_SIG_OFFSET + 1]) if len(data) > BOOT_SIG_OFFSET + 1 else (0, 0)
    sig_ok = actual_sig in VALID_BOOT_SIGS
    checks.append({
        "name": "Boot signature",
        "passed": sig_ok,
        "message": f"0x{actual_sig[0]:02X} 0x{actual_sig[1]:02X} "
                   f"({'OK' if sig_ok else 'not a recognized EMXP boot signature'})",
    })

    # 2. FAT entry 0
    fat_entry0 = (data[FAT_OFFSET] | (data[FAT_OFFSET + 1] << 8)) if len(data) > FAT_OFFSET + 1 else -1
    fat0_ok = fat_entry0 == 0x8000
    checks.append({
        "name": "FAT entry 0",
        "passed": fat0_ok,
        "message": f"0x{fat_entry0:04X} ({'OK' if fat0_ok else 'expected 0x8000'})",
    })

    # 3. FAT entry 1 (OS chain - non-zero means OS present)
    fat_entry1 = (data[FAT_OFFSET + 2] | (data[FAT_OFFSET + 3] << 8)) if len(data) > FAT_OFFSET + 3 else 0
    fat1_ok = fat_entry1 != 0
    checks.append({
        "name": "FAT entry 1 (OS chain)",
        "passed": fat1_ok,
        "message": f"0x{fat_entry1:04X} ({'chain present' if fat1_ok else 'empty - no OS'})",
    })

    # 4. Catalog OS entry
    cat_name = data[CATALOG_OFFSET:CATALOG_OFFSET + 16].rstrip(b'\x00')
    catalog_ok = len(cat_name) > 0
    checks.append({
        "name": "Catalog OS entry",
        "passed": catalog_ok,
        "message": cat_name.decode("latin-1", errors="replace") if catalog_ok else "(empty)",
    })

    # 5. File size — EMXP sizes don't divide evenly by 1MB, use known byte sizes
    VALID_BYTE_SIZES = {
        96:  100528128,   # Exact EMXP template sizes (verified)
        239: 250398720,
        481: 503900160,
        633: 663302144,
        962: 1007765504,
    }
    size_bytes = len(data)
    size_ok = size_bytes in VALID_BYTE_SIZES.values()
    size_mb = next((k for k, v in VALID_BYTE_SIZES.items() if v == size_bytes), size_bytes // (1024 * 1024))
    checks.append({
        "name": "File size",
        "passed": size_ok,
        "message": f"{size_mb} MB ({'recognized' if size_ok else 'unrecognized size'})",
    })

    valid = all(c["passed"] for c in checks)
    return {
        "disk_path": str(p),
        "valid": valid,
        "size_mb": size_mb,
        "checks": checks,
    }


def list_images(directory: str) -> dict:
    """
    List all EMAX II disk images in a directory (HD and FD prefixes).

    Returns:
        Dict with image list
    """
    d = Path(directory)
    if not d.is_dir():
        raise FileNotFoundError(f"Directory not found: {directory}")

    images = []
    extensions = {".hda", ".ez2", ".img", ".iso", ".hfe", ".dsk"}
    for f in sorted(d.iterdir()):
        if not f.is_file():
            continue
        if f.suffix.lower() not in extensions:
            continue

        name_upper = f.stem.upper()
        is_hd = name_upper.startswith("HD")
        is_fd = name_upper.startswith("FD")
        size_bytes = f.stat().st_size
        size_mb = size_bytes // (1024 * 1024)

        images.append({
            "filename": f.name,
            "path": str(f),
            "type": "floppy" if (is_fd or f.suffix.lower() in {".hfe", ".dsk"}) else "hd",
            "size_mb": size_mb,
            "size_bytes": size_bytes,
            "scsi_id": _parse_scsi_id(f.stem),
            "is_boot": is_hd and name_upper.startswith("HD1"),  # HD10/HD1x = SCSI 1
        })

    return {
        "directory": str(d),
        "count": len(images),
        "images": images,
    }


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _find_os_bin() -> Path | None:
    """Locate the EMAX II OS binary (emax2_os.bin in Resources)."""
    candidates = [
        Path(__file__).parents[4] / "EmaxForge" / "Resources" / "emax2_os.bin",
        Path(__file__).parents[5] / "EmaxForge" / "Resources" / "emax2_os.bin",
        Path(__file__).parents[4] / "Resources" / "emax2_os.bin",
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


def _find_template(size_mb: int) -> Path:
    """Locate the EZ2 template file for the given size."""
    filename = TEMPLATE_MAP[size_mb]
    candidates = [
        # Relative to this file → project root → Resources
        Path(__file__).parents[4] / "EmaxForge" / "Resources" / "bootable_templates" / filename,
        Path(__file__).parents[5] / "EmaxForge" / "Resources" / "bootable_templates" / filename,
        Path(__file__).parents[4] / "Resources" / "bootable_templates" / filename,
    ]
    for c in candidates:
        if c.exists():
            return c
    raise FileNotFoundError(
        f"Template '{filename}' not found. Searched:\n" +
        "\n".join(f"  {c}" for c in candidates)
    )


def _zuluscsi_name(scsi_id: int) -> str:
    return f"HD{scsi_id}0.hda"


def _parse_scsi_id(stem: str) -> int | None:
    upper = stem.upper()
    for prefix in ("HD", "FD"):
        if upper.startswith(prefix) and len(upper) >= 3:
            try:
                return int(upper[len(prefix)])
            except ValueError:
                pass
    return None
