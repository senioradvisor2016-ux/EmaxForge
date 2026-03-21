"""Floppy/Gotek disk operations for EmaxForge CLI-Anything harness"""

import struct
from pathlib import Path


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

FLOPPY_SIZES = {
    "180K":  {"bytes": 184_320,   "tracks": 40, "sides": 1, "sectors": 9,  "label": "Single Density 180 KB"},
    "800K":  {"bytes": 819_200,   "tracks": 80, "sides": 2, "sectors": 10, "label": "Double Density 800 KB (EMAX II standard)"},
    "1440K": {"bytes": 1_474_560, "tracks": 80, "sides": 2, "sectors": 18, "label": "High Density 1.44 MB"},
}

# HFE file magic
HFE_MAGIC = b"HXCPICFE"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def create_floppy(size: str, output_path: str, format_type: str = "emax") -> dict:
    """
    Create a blank EMAX II floppy disk image.

    Args:
        size: One of "180K", "800K", "1440K"
        output_path: Destination file (.img or .hfe)
        format_type: "emax" (raw) or "hfe" (HxC Floppy Emulator)

    Returns:
        Dict with floppy info
    """
    if size not in FLOPPY_SIZES:
        raise ValueError(f"Invalid size '{size}'. Choose from: {list(FLOPPY_SIZES)}")

    spec = FLOPPY_SIZES[size]
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    if format_type == "hfe" or output.suffix.lower() == ".hfe":
        data = _build_hfe(spec)
    else:
        data = bytes(spec["bytes"])  # raw blank image

    output.write_bytes(data)

    return {
        "path": str(output),
        "format": "hfe" if (format_type == "hfe" or output.suffix.lower() == ".hfe") else "raw",
        "size_label": spec["label"],
        "size_bytes": len(data),
        "tracks": spec["tracks"],
        "sides": spec["sides"],
        "sectors_per_track": spec["sectors"],
    }


def list_floppies(directory: str) -> dict:
    """
    Scan a directory for floppy images (FD prefix or .hfe/.dsk extension).

    Args:
        directory: Directory to scan

    Returns:
        Dict with list of floppy images
    """
    d = Path(directory)
    if not d.is_dir():
        raise FileNotFoundError(f"Directory not found: {directory}")

    images = []
    extensions = {".hfe", ".dsk", ".img"}
    for f in sorted(d.iterdir()):
        name_upper = f.stem.upper()
        is_fd = name_upper.startswith("FD")
        is_floppy_ext = f.suffix.lower() in {".hfe", ".dsk"}
        size_bytes = f.stat().st_size if f.is_file() else 0

        if f.is_file() and (is_fd or is_floppy_ext) and f.suffix.lower() in extensions | {".hfe", ".dsk"}:
            floppy_size = _detect_size(size_bytes)
            images.append({
                "filename": f.name,
                "path": str(f),
                "size_bytes": size_bytes,
                "size_label": floppy_size["label"] if floppy_size else "Unknown",
                "format": _detect_format(f),
                "fd_index": _parse_fd_index(f.stem),
            })

    return {"directory": str(d), "count": len(images), "images": images}


def convert_hfe_to_img(hfe_path: str, output_path: str) -> dict:
    """
    Convert an HFE floppy image to raw IMG format.

    A minimal conversion that strips the HFE header/track table and
    writes raw sector data.  Handles standard MFM/FM HFE v1 images.
    """
    src = Path(hfe_path)
    if not src.exists():
        raise FileNotFoundError(f"HFE file not found: {hfe_path}")

    data = src.read_bytes()

    if data[:8] != HFE_MAGIC:
        raise ValueError("Not a valid HFE file (magic mismatch)")

    # HFE v1 header layout (little-endian)
    # 0x00: magic (8)
    # 0x08: format_revision (1)
    # 0x09: number_of_track (1)
    # 0x0A: number_of_side (1)
    # 0x0B: track_encoding (1)
    # 0x0C: bitRate (2)  kbps
    # 0x0E: floppyRPM (2)
    # 0x10: floppyinterfacemode (1)
    # 0x11: dnu (1)
    # 0x12: track_list_offset (2)  in 512-byte blocks
    num_tracks = data[0x09]
    num_sides = data[0x0A]
    track_list_offset = struct.unpack_from("<H", data, 0x12)[0] * 512

    # Track list: each entry is 4 bytes (offset in 512-blocks, track_len in bytes)
    raw_sectors = bytearray()
    for t in range(num_tracks):
        entry_off = track_list_offset + t * 4
        track_block_offset = struct.unpack_from("<H", data, entry_off)[0] * 512
        track_len = struct.unpack_from("<H", data, entry_off + 2)[0]
        # Track data is interleaved: side0 | side1 (each track_len/2 bytes)
        half = track_len // 2
        raw_sectors += data[track_block_offset: track_block_offset + half]
        if num_sides == 2:
            raw_sectors += data[track_block_offset + half: track_block_offset + track_len]

    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(bytes(raw_sectors))

    return {
        "source": str(src),
        "output": str(out),
        "tracks": num_tracks,
        "sides": num_sides,
        "size_bytes": len(raw_sectors),
    }


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _build_hfe(spec: dict) -> bytes:
    """Build a minimal blank HFE v1 image."""
    num_tracks = spec["tracks"]
    num_sides = spec["sides"]
    sectors = spec["sectors"]
    bytes_per_sector = 512
    # MFM encoding: ~2x overhead, simplified to raw bytes for blank image
    track_data_bytes = sectors * bytes_per_sector  # per side
    full_track_len = track_data_bytes * num_sides  # interleaved

    # Pad track data to 512-byte blocks
    padded_track_len = ((full_track_len + 511) // 512) * 512

    # Track list starts at block 1 (offset 512)
    track_list_block = 1
    # Track data starts after header block + track_list_blocks
    track_list_size_bytes = ((num_tracks * 4 + 511) // 512) * 512
    track_list_blocks = track_list_size_bytes // 512
    first_track_block = track_list_block + track_list_blocks

    # --- Header (512 bytes) ---
    header = bytearray(512)
    header[0:8] = HFE_MAGIC
    header[0x08] = 0          # format_revision
    header[0x09] = num_tracks
    header[0x0A] = num_sides
    header[0x0B] = 0          # ISOIBM_MFM_ENCODING
    struct.pack_into("<H", header, 0x0C, 250)  # bitRate 250 kbps
    struct.pack_into("<H", header, 0x0E, 300)  # 300 RPM
    header[0x10] = 0xFF       # DISABLE_FLOPPYMODE
    header[0x11] = 0xFF       # dnu
    struct.pack_into("<H", header, 0x12, track_list_block)
    header[0x14] = 0xFF       # write_allowed
    header[0x15] = 0xFF       # single_step
    header[0x16] = 0xFF       # track0s0_altencoding
    header[0x17] = 0xFF       # track0s0_encoding
    header[0x18] = 0xFF       # track0s1_altencoding
    header[0x19] = 0xFF       # track0s1_encoding

    # --- Track list (variable, padded to 512-byte blocks) ---
    track_list = bytearray(track_list_size_bytes)
    for t in range(num_tracks):
        track_block = first_track_block + t * (padded_track_len // 512)
        struct.pack_into("<H", track_list, t * 4, track_block)
        struct.pack_into("<H", track_list, t * 4 + 2, full_track_len)

    # --- Blank track data ---
    all_tracks = bytearray()
    for _ in range(num_tracks):
        track = bytearray(padded_track_len)
        # Fill with 0x4E (MFM gap filler)
        for i in range(len(track)):
            track[i] = 0x4E
        all_tracks += track

    return bytes(header) + bytes(track_list) + bytes(all_tracks)


def _detect_size(size_bytes: int) -> dict | None:
    for key, spec in FLOPPY_SIZES.items():
        if abs(spec["bytes"] - size_bytes) < spec["bytes"] // 20:
            return spec
    return None


def _detect_format(path: Path) -> str:
    if path.suffix.lower() == ".hfe":
        try:
            data = path.read_bytes()[:8]
            return "hfe" if data == HFE_MAGIC else "unknown"
        except Exception:
            return "hfe"
    if path.suffix.lower() == ".dsk":
        return "dsk"
    return "raw"


def _parse_fd_index(stem: str) -> int | None:
    upper = stem.upper()
    if upper.startswith("FD") and len(upper) >= 4:
        try:
            return int(upper[2:4])
        except ValueError:
            pass
    return None
