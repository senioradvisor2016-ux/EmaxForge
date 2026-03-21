#!/usr/bin/env python3
"""Debug FAT chain issues in EMAX II disk images."""

import struct
import sys
import os

image_path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/clawd/emxp/Images/EmaxII-02.EZ2")

with open(image_path, "rb") as f:
    # Header
    hdr = f.read(512)

magic = hdr[0:4].decode("ascii", errors="replace")
cluster_size    = struct.unpack_from("<I", hdr, 0x04)[0]
bnt_start_sec   = struct.unpack_from("<I", hdr, 0x10)[0]
max_banks       = struct.unpack_from("<I", hdr, 0x14)[0]
fat_sectors     = struct.unpack_from("<I", hdr, 0x1C)[0]
ca_start_sec    = struct.unpack_from("<I", hdr, 0x20)[0]

fat_size   = fat_sectors * 512
bnt_offset = bnt_start_sec * 512
bnt_size   = (ca_start_sec - bnt_start_sec) * 512
ca_offset  = ca_start_sec * 512

print(f"Magic:          {magic!r}")
print(f"clusterSize:    {cluster_size}")
print(f"bntStartSector: {bnt_start_sec} → 0x{bnt_offset:X}")
print(f"maxBanks:       {max_banks}")
print(f"fatSectors:     {fat_sectors} → fatSize={fat_size} bytes ({fat_size//2} entries)")
print(f"caStartSector:  {ca_start_sec} → 0x{ca_offset:X}")
print()

with open(image_path, "rb") as f:
    # FAT at 0x400
    f.seek(0x400)
    fat_data = f.read(fat_size)

    # BNT
    f.seek(bnt_offset)
    bnt_data = f.read(bnt_size)

fat_entries = fat_size // 2

print(f"FAT[0] = 0x{struct.unpack_from('<H', fat_data, 0)[0]:04X}")
print(f"FAT[1] = 0x{struct.unpack_from('<H', fat_data, 2)[0]:04X}")
print(f"FAT[2] = 0x{struct.unpack_from('<H', fat_data, 4)[0]:04X}")
print(f"FAT[3] = 0x{struct.unpack_from('<H', fat_data, 6)[0]:04X}")
print()

def fat_chain(start, fat_data, fat_entries, max_clusters=200):
    """Follow FAT chain from start cluster."""
    clusters = []
    cur = start
    seen = set()
    while 0 < cur < fat_entries and len(clusters) < max_clusters:
        if cur in seen:
            return clusters, "LOOP"
        seen.add(cur)
        clusters.append(cur)
        nxt = struct.unpack_from("<H", fat_data, cur * 2)[0]
        if nxt == 0x7FFF:
            return clusters, "EOC"
        if nxt == 0x8000:
            return clusters, "EOC(8000)"
        if nxt == 0x0000:
            return clusters, f"BROKEN(FAT[{cur}]=0)"
        cur = nxt
    return clusters, "MAXED"

# Parse BNT
max_slots = min(max_banks + 1, bnt_size // 32)
print(f"{'Slot':<5} {'Name':<20} {'Start':>6} {'BNT_cnt':>8} {'FAT_cnt':>8}  Status  Chain")
print("-" * 80)

broken = []
for i in range(max_slots):
    off = i * 32
    if off + 32 > len(bnt_data):
        break
    entry = bnt_data[off:off+32]
    if all(b == 0 for b in entry):
        continue
    if all(b == 0xFF for b in entry):
        continue

    flags = struct.unpack_from("<H", entry, 26)[0]
    name_raw = entry[0:14]
    name = name_raw.split(b'\x00')[0].decode("ascii", errors="replace").strip()
    start = struct.unpack_from("<H", entry, 18)[0]
    bnt_cnt = struct.unpack_from("<H", entry, 20)[0]

    if not name:
        continue

    clusters, status = fat_chain(start, fat_data, fat_entries)
    chain_preview = "→".join(str(c) for c in clusters[:6]) + ("→..." if len(clusters) > 6 else "")

    mark = "✅" if status in ("EOC", "EOC(8000)") else "❌"
    print(f"  {i:<4} {name:<20} {start:>6} {bnt_cnt:>8} {len(clusters):>8}  {mark} {status:<15} {chain_preview}")

    if "BROKEN" in status or status == "LOOP":
        broken.append((name, start, bnt_cnt, status))

print()
if broken:
    print(f"❌ {len(broken)} broken chains:")
    for b in broken:
        print(f"   '{b[0]}' start={b[1]} bnt_cnt={b[2]} → {b[3]}")
    
    # Diagnose: show raw FAT around broken clusters
    print()
    print("Raw FAT dump around broken clusters:")
    for name, start, bnt_cnt, _ in broken[:3]:
        print(f"  [{name}] start={start}:")
        for c in range(max(1, start-2), min(fat_entries, start+bnt_cnt+5)):
            val = struct.unpack_from("<H", fat_data, c * 2)[0]
            print(f"    FAT[{c:4d}] = 0x{val:04X}")
else:
    print("✅ All FAT chains OK!")
