#!/usr/bin/env python3
"""
Byte-for-byte bank data comparison between EMXP gold disk and EmaxForge disk.
Reads BNT to find each bank's cluster chain, extracts raw cluster data, compares.
"""
import sys
import struct

CLUSTER_SIZE = 489472  # verified from disk headers
BNT_OFFSET = 0x1000
BNT_ENTRY_SIZE = 32
CA_OFFSET = 0xC400  # cluster area start

def read_u16le(data, offset):
    return struct.unpack_from('<H', data, offset)[0]

def read_u32le(data, offset):
    return struct.unpack_from('<I', data, offset)[0]

def get_fat(disk_data):
    """Read FAT (sector 1, offset 0x200, 16-bit LE entries)"""
    fat = []
    offset = 0x200
    while offset + 2 <= 0x1000:
        fat.append(read_u16le(disk_data, offset))
        offset += 2
    return fat

def get_cluster_chain(fat, start_cluster):
    """Follow FAT chain from start_cluster. Returns list of cluster indices."""
    chain = []
    current = start_cluster
    visited = set()
    while current not in visited and current != 0 and current < len(fat):
        chain.append(current)
        visited.add(current)
        next_c = fat[current]
        if next_c >= 0x7FFF or next_c == 0:
            break
        current = next_c
    return chain

def extract_bank_data(disk_data, fat, start_cluster):
    """Extract raw bytes for all clusters in bank's chain."""
    chain = get_cluster_chain(fat, start_cluster)
    data = b''
    for cl in chain:
        # 1-based: cluster 1 = CA_OFFSET + 0, cluster 2 = CA_OFFSET + CLUSTER_SIZE, etc.
        offset = CA_OFFSET + (cl - 1) * CLUSTER_SIZE
        data += disk_data[offset:offset + CLUSTER_SIZE]
    return data, chain

def read_bnt_entry(disk_data, slot):
    offset = BNT_OFFSET + slot * BNT_ENTRY_SIZE
    entry = disk_data[offset:offset + BNT_ENTRY_SIZE]
    name = entry[0:12].rstrip(b'\x00').decode('ascii', errors='replace')
    start_cluster = read_u16le(entry, 18)
    cluster_count = read_u16le(entry, 20)
    flags = read_u16le(entry, 26)
    return name, start_cluster, cluster_count, flags

def compare_disks(gold_path, emf_path, slots):
    with open(gold_path, 'rb') as f:
        gold = f.read()
    with open(emf_path, 'rb') as f:
        emf = f.read()

    gold_fat = get_fat(gold)
    emf_fat = get_fat(emf)

    print(f"{'='*60}")
    print(f"BANK VERIFICATION: byte-for-byte comparison")
    print(f"GOLD: {gold_path}")
    print(f"EMF:  {emf_path}")
    print(f"{'='*60}\n")

    all_pass = True

    for slot in slots:
        g_name, g_start, g_count, g_flags = read_bnt_entry(gold, slot)
        e_name, e_start, e_count, e_flags = read_bnt_entry(emf, slot)

        print(f"Slot {slot}: GOLD='{g_name}' (cl={g_start}, cnt={g_count})  EMF='{e_name}' (cl={e_start}, cnt={e_count})")

        if g_start == 0:
            print(f"  ⚠️  GOLD slot {slot} is empty — skipping\n")
            continue

        if e_start == 0:
            print(f"  ❌ EMF slot {slot} is empty!\n")
            all_pass = False
            continue

        # Extract raw cluster data
        g_data, g_chain = extract_bank_data(gold, gold_fat, g_start)
        e_data, e_chain = extract_bank_data(emf, emf_fat, e_start)

        print(f"  GOLD chain: {g_chain} ({len(g_data)} bytes)")
        print(f"  EMF  chain: {e_chain} ({len(e_data)} bytes)")

        if len(g_data) != len(e_data):
            print(f"  ❌ SIZE MISMATCH: {len(g_data)} vs {len(e_data)}\n")
            all_pass = False
            continue

        # Byte-for-byte compare
        diffs = [(i, g_data[i], e_data[i]) for i in range(len(g_data)) if g_data[i] != e_data[i]]

        if not diffs:
            print(f"  ✅ IDENTICAL — {len(g_data)} bytes match perfectly!\n")
        else:
            print(f"  ❌ {len(diffs)} bytes differ:")
            # Show first 10 diffs
            for i, gb, eb in diffs[:10]:
                cl_idx = i // CLUSTER_SIZE + 1
                cl_off = i % CLUSTER_SIZE
                print(f"     offset 0x{i:08X} (cluster {cl_idx}+0x{cl_off:05X}): GOLD=0x{gb:02X} EMF=0x{eb:02X}")
            if len(diffs) > 10:
                print(f"     ... and {len(diffs)-10} more")
            all_pass = False
            print()

    print(f"{'='*60}")
    if all_pass:
        print("🎉 ALL BANKS IDENTICAL — EmaxForge is byte-for-byte compatible!")
    else:
        print("⚠️  DIFFERENCES FOUND — see above")
    print(f"{'='*60}")

if __name__ == '__main__':
    GOLD = "/Volumes/EMAX DRIVE/ZuluSCSI_EMAX2/HD10.hda"
    EMF  = "/Users/senioradvisor/clawd/EmaxForge/verification/bank_verify/emf_test.hda"
    # Slots 1-5 (skip slot 0 = OS)
    compare_disks(GOLD, EMF, slots=[1, 2, 3, 4, 5])
