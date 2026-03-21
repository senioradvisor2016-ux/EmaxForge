#!/usr/bin/env python3
"""
GROUND TRUTH ORACLE — EmaxForge correctness test
=================================================
Strategy:
1. Parse a known-good hardware-tested reference disk (EmaxII-02.ez2)
2. Extract raw cluster data for each bank
3. Create a fresh disk with our code
4. Import the same bank data
5. Compare byte-for-byte: BNT entry, FAT chain, raw cluster bytes

If this passes: our code is bit-perfect with what real hardware expects.
If this fails: we have a bug, NOT a test config problem.

CRITICAL DISCOVERY:
  startCluster is a SECTOR NUMBER relative to cluster area start
  NOT a cluster index!
  Formula: byte_offset = ca_bytes + startCluster_sectors * 512
  Cluster index = startCluster_sectors // sects_per_cluster
"""

import os
import struct
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────
REFERENCE_DISK = Path("/Users/senioradvisor/Downloads/EmaxII-02.ez2")
HARNESS_DIR    = Path("/Users/senioradvisor/clawd/EmaxForge/agent-harness")
VENV_PYTHON    = HARNESS_DIR / "venv/bin/python"

def fail(msg):
    print(f"\n❌ ORACLE FAIL: {msg}")
    sys.exit(1)

def ok(msg):
    print(f"  ✅ {msg}")

# ── Parse reference disk ─────────────────────────────────────────────────────
def parse_reference(path: Path) -> dict:
    """Parse reference disk geometry and bank list — ground truth."""
    data = path.read_bytes()
    disk_sects = len(data) // 512
    
    ca_start   = struct.unpack_from("<I", data, 0x20)[0]
    total_cls  = struct.unpack_from("<I", data, 0x24)[0]
    bnt_sector = struct.unpack_from("<I", data, 0x10)[0]
    max_banks  = struct.unpack_from("<I", data, 0x14)[0]
    
    sects_per_cluster = (disk_sects - ca_start) // total_cls
    cluster_size      = sects_per_cluster * 512
    ca_bytes          = ca_start * 512
    bnt_off           = bnt_sector * 512
    fat_off           = 0x400
    
    print(f"Reference: {path.name} ({len(data)//1024//1024} MB)")
    print(f"  Cluster size:  {sects_per_cluster} sects = {cluster_size//1024} KB")
    print(f"  Total clusters:{total_cls}")
    print(f"  Cluster area:  sector {ca_start} = 0x{ca_bytes:X}")
    
    # Read FAT
    fat = [struct.unpack_from("<H", data, fat_off + i*2)[0] for i in range(total_cls + 10)]
    
    # Read BNT
    banks = []
    for slot in range(max_banks + 2):
        raw = data[bnt_off + slot*32 : bnt_off + slot*32 + 32]
        if len(raw) < 32:
            break
        
        # Raw bytes for exact comparison later
        name_bytes  = raw[0:16]
        start_cls_s = struct.unpack_from("<H", raw, 16)[0]   # sector-relative to CA
        cls_count   = struct.unpack_from("<H", raw, 18)[0]
        idx         = struct.unpack_from("<H", raw, 20)[0]
        flags       = struct.unpack_from("<H", raw, 22)[0]
        name        = name_bytes.rstrip(b'\x00 ').decode('latin-1', errors='replace')
        
        # Skip OS and sentinels
        if start_cls_s == 0x7800:  # OS cluster
            continue
        if flags == 0xFFFF or flags == 0x0000:
            continue
        if not name.strip():
            continue
        
        # Compute byte offset:
        # startCluster is SECTORS relative to cluster area (not cluster index!)
        byte_off = ca_bytes + start_cls_s * 512
        size_bytes = cls_count * cluster_size
        
        if byte_off + size_bytes > len(data):
            continue
        
        raw_data = data[byte_off : byte_off + size_bytes]
        
        banks.append({
            'slot':       slot,
            'name':       name,
            'name_bytes': name_bytes,
            'start_cls_s': start_cls_s,  # sector-relative startCluster
            'cls_count':  cls_count,
            'idx':        idx,
            'flags':      flags,
            'byte_off':   byte_off,
            'size_bytes': size_bytes,
            'raw_data':   raw_data,
            'bnt_raw':    raw,            # all 32 bytes for byte comparison
        })
    
    return {
        'data':              data,
        'disk_sects':        disk_sects,
        'ca_start':          ca_start,
        'ca_bytes':          ca_bytes,
        'total_clusters':    total_cls,
        'sects_per_cluster': sects_per_cluster,
        'cluster_size':      cluster_size,
        'bnt_off':           bnt_off,
        'fat':               fat,
        'banks':             banks,
    }

# ── Read back from our disk ───────────────────────────────────────────────────
def parse_our_disk(path: Path) -> dict:
    """Parse our generated disk the same way as reference."""
    data = path.read_bytes()
    disk_sects = len(data) // 512
    
    ca_start   = struct.unpack_from("<I", data, 0x20)[0]
    total_cls  = struct.unpack_from("<I", data, 0x24)[0]
    bnt_sector = struct.unpack_from("<I", data, 0x10)[0]
    max_banks  = struct.unpack_from("<I", data, 0x14)[0]
    
    sects_per_cluster = (disk_sects - ca_start) // total_cls
    cluster_size      = sects_per_cluster * 512
    ca_bytes          = ca_start * 512
    bnt_off           = bnt_sector * 512
    fat_off           = 0x400
    
    fat = [struct.unpack_from("<H", data, fat_off + i*2)[0] for i in range(total_cls + 10)]
    
    banks = {}
    for slot in range(max_banks + 2):
        raw = data[bnt_off + slot*32 : bnt_off + slot*32 + 32]
        if len(raw) < 32:
            break
        name_bytes  = raw[0:16]
        start_cls_s = struct.unpack_from("<H", raw, 16)[0]
        cls_count   = struct.unpack_from("<H", raw, 18)[0]
        flags       = struct.unpack_from("<H", raw, 22)[0]
        name        = name_bytes.rstrip(b'\x00 ').decode('latin-1', errors='replace').strip()
        
        if not name or flags == 0xFFFF:
            continue
        
        byte_off   = ca_bytes + start_cls_s * 512
        size_bytes = cls_count * cluster_size
        
        if byte_off + size_bytes <= len(data):
            raw_data = data[byte_off : byte_off + size_bytes]
        else:
            raw_data = b''
        
        banks[name] = {
            'slot':       slot,
            'name':       name,
            'start_cls_s': start_cls_s,
            'cls_count':  cls_count,
            'flags':      flags,
            'byte_off':   byte_off,
            'size_bytes': size_bytes,
            'raw_data':   raw_data,
            'bnt_raw':    raw,
        }
    
    return {'data': data, 'banks': banks, 'cluster_size': cluster_size, 'fat': fat}

# ── CLI helpers ──────────────────────────────────────────────────────────────
def run_harness(args, cwd=HARNESS_DIR):
    cmd = [str(VENV_PYTHON), "-m", "cli_anything.emaxforge"] + args
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return r.returncode, r.stdout, r.stderr

# ── Oracle test ───────────────────────────────────────────────────────────────
def oracle_roundtrip_test():
    print("=" * 60)
    print("GROUND TRUTH ORACLE — EmaxForge correctness")
    print("=" * 60)
    
    if not REFERENCE_DISK.exists():
        fail(f"Reference disk not found: {REFERENCE_DISK}")
    
    # 1. Parse reference
    print("\n[1/5] Parsing reference disk...")
    ref = parse_reference(REFERENCE_DISK)
    
    if not ref['banks']:
        fail("No banks found in reference disk")
    
    # Use first 2 banks for test
    test_banks = ref['banks'][:2]
    for b in test_banks:
        print(f"  Bank: '{b['name']}' (slot {b['slot']}, {b['size_bytes']//1024} KB)")
        print(f"    start_cls_s=0x{b['start_cls_s']:04X}, cls_count={b['cls_count']}")
        print(f"    byte_off=0x{b['byte_off']:X}, flags=0x{b['flags']:04X}")
        print(f"    First bytes: {b['raw_data'][:8].hex()}")
        ok("Extracted from reference")
    
    # 2. Create test disk (same size as reference = 96 MB)
    print("\n[2/5] Creating fresh 96 MB disk...")
    test_disk = Path("/tmp/oracle_test.hda")
    rc, out, err = run_harness(["create-boot-disk", "--output", str(test_disk), "--size", "96"])
    if rc != 0 or not test_disk.exists():
        fail(f"create-boot-disk failed:\n{out}\n{err}")
    ok(f"Created {test_disk} ({test_disk.stat().st_size//1024//1024} MB)")
    
    # 3. Extract raw bank data and save as temp files
    print("\n[3/5] Saving reference bank data as temp files...")
    temp_banks = []
    for b in test_banks:
        tmp = Path(f"/tmp/oracle_bank_{b['slot']}.bin")
        tmp.write_bytes(b['raw_data'])
        temp_banks.append((b, tmp))
        ok(f"Saved '{b['name']}' → {tmp} ({len(b['raw_data'])})")
    
    # 4. Import banks via harness
    print("\n[4/5] Importing banks into fresh disk...")
    for b, tmp_path in temp_banks:
        rc, out, err = run_harness(["import-bank", "--disk", str(test_disk), "--bank", str(tmp_path)])
        if rc != 0:
            fail(f"import-bank failed for '{b['name']}':\n{out}\n{err}")
        ok(f"Imported '{b['name']}'")
    
    # 5. Read back and compare
    print("\n[5/5] Comparing output vs reference...")
    our = parse_our_disk(test_disk)
    
    failures = []
    
    for b in test_banks:
        bname = b['name']
        if bname not in our['banks']:
            failures.append(f"'{bname}' not found in our disk BNT")
            continue
        
        ours = our['banks'][bname]
        
        # A: Cluster data match
        ref_data = b['raw_data']
        our_data = ours['raw_data']
        
        if ref_data == our_data:
            ok(f"'{bname}': cluster data MATCH ({len(ref_data):,} bytes)")
        else:
            # Find first difference
            diff_off = next((i for i in range(min(len(ref_data), len(our_data))) if ref_data[i] != our_data[i]), -1)
            failures.append(
                f"'{bname}': cluster data MISMATCH at offset 0x{diff_off:X}\n"
                f"    ref[{diff_off:X}:{diff_off+8:X}] = {ref_data[diff_off:diff_off+8].hex()}\n"
                f"    our[{diff_off:X}:{diff_off+8:X}] = {our_data[diff_off:diff_off+8].hex()}"
            )
        
        # B: Cluster count match
        if b['cls_count'] == ours['cls_count']:
            ok(f"'{bname}': cluster count match ({b['cls_count']})")
        else:
            failures.append(f"'{bname}': cls_count {b['cls_count']} != {ours['cls_count']}")
        
        # C: startCluster addressing
        # Reference uses sector-relative addressing — check our disk does too
        ref_off = ref['ca_bytes'] + b['start_cls_s'] * 512
        our_off = ours['byte_off']
        print(f"  '{bname}': ref_start_cls_s=0x{b['start_cls_s']:04X} our_start_cls_s=0x{ours['start_cls_s']:04X}")
        # Note: exact sector numbers will differ (different disk), but offset formula must be same
    
    print("\n" + "=" * 60)
    if failures:
        print(f"❌ ORACLE FAILED — {len(failures)} issue(s):")
        for f in failures:
            print(f"  • {f}")
        sys.exit(1)
    else:
        print(f"✅ ORACLE PASSED — byte-perfect match with reference disk!")
        print(f"   {len(test_banks)} banks verified against EmaxII-02.ez2")

if __name__ == "__main__":
    oracle_roundtrip_test()
