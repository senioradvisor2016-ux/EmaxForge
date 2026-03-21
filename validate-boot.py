#!/usr/bin/env python3
"""
EmaxForge Boot Validator
Compares a disk image against the known-working Funkar/HD10.hda
Reports PASS/FAIL for each critical boot requirement.

Usage: python3 validate-boot.py <image.hda> [--fix]
"""

import sys
import os
import struct

WORKING_DISK = os.path.expanduser("~/clawd/SD_BOOT/Funkar/HD10.hda")

# Known templates by file size
TEMPLATES = {
    # size_bytes: (name, clusterAreaStartSector, clusterSize, bootSig1, bootSig2, bankCount)
    100646400:  ("96 MB",  120, 489984,  0x93, 0xA1, 111),
    250398720:  ("239 MB",  98, 489472,  0x78, 0x82,  90),
    504365568:  ("481 MB", 115, 984576,  0x65, 0x9F, 106),
    663748608:  ("633 MB", 147, 1296384, 0xAA, 0xCF, 105),
    1008730112: ("962 MB", 163, 1961984, 0xFC, 0x73, 105),
}

class Colors:
    OK = '\033[92m'
    FAIL = '\033[91m'
    WARN = '\033[93m'
    BOLD = '\033[1m'
    END = '\033[0m'

def ok(msg):   return f"{Colors.OK}✅ PASS{Colors.END} {msg}"
def fail(msg): return f"{Colors.FAIL}❌ FAIL{Colors.END} {msg}"
def warn(msg): return f"{Colors.WARN}⚠️  WARN{Colors.END} {msg}"

def read_u16le(data, offset):
    return struct.unpack_from('<H', data, offset)[0]

def read_u32le(data, offset):
    return struct.unpack_from('<I', data, offset)[0]

def validate(image_path, compare_working=True):
    print(f"\n{Colors.BOLD}🔬 EmaxForge Boot Validator{Colors.END}")
    print(f"{'='*60}")
    print(f"Image: {image_path}")
    
    if not os.path.exists(image_path):
        print(fail(f"File not found: {image_path}"))
        return False
    
    file_size = os.path.getsize(image_path)
    print(f"Size:  {file_size:,} bytes ({file_size // 1048576} MB)")
    
    # Find template
    template = TEMPLATES.get(file_size)
    if not template:
        print(fail(f"Unknown disk size. Expected: {list(TEMPLATES.keys())}"))
        return False
    
    tname, cas_sector, cluster_size, boot_sig1, boot_sig2, bank_count = template
    catalog_offset = cas_sector * 512
    os_data_offset = catalog_offset + 4896  # Catalog size = 0x1320 = 4896
    
    print(f"Type:  {tname} (clusterAreaStart=sector {cas_sector}, offset 0x{catalog_offset:X})")
    print(f"{'='*60}\n")
    
    with open(image_path, 'rb') as f:
        data = f.read(os_data_offset + cluster_size)  # Read up to OS data + one cluster
    
    passed = 0
    failed = 0
    warnings = 0
    
    # Load working disk for comparison
    work_data = None
    if compare_working and os.path.exists(WORKING_DISK):
        work_size = os.path.getsize(WORKING_DISK)
        if work_size == file_size:
            with open(WORKING_DISK, 'rb') as f:
                work_data = f.read(os_data_offset + cluster_size)
            print(f"Reference: {WORKING_DISK}")
            print()
    
    # ===== TEST 1: Magic =====
    magic = data[0:4].decode('ascii', errors='replace')
    if magic == 'EMX2':
        print(ok(f"Magic: '{magic}'"))
        passed += 1
    else:
        print(fail(f"Magic: '{magic}' (expected 'EMX2')"))
        failed += 1
    
    # ===== TEST 2: Boot Signature =====
    sig1 = data[0x1FE]
    sig2 = data[0x1FF]
    if sig1 == boot_sig1 and sig2 == boot_sig2:
        print(ok(f"Boot signature: 0x{sig1:02X}{sig2:02X}"))
        passed += 1
    else:
        print(fail(f"Boot signature: 0x{sig1:02X}{sig2:02X} (expected 0x{boot_sig1:02X}{boot_sig2:02X})"))
        failed += 1
    
    # ===== TEST 3: Header fields =====
    h_cluster_size = read_u32le(data, 0x04)
    h_cas = read_u32le(data, 0x20)
    h_bank_count = read_u32le(data, 0x14)
    
    if h_cluster_size == cluster_size:
        print(ok(f"Cluster size: {h_cluster_size} bytes"))
        passed += 1
    else:
        print(fail(f"Cluster size: {h_cluster_size} (expected {cluster_size})"))
        failed += 1
    
    if h_cas == cas_sector:
        print(ok(f"Cluster area start: sector {h_cas}"))
        passed += 1
    else:
        print(fail(f"Cluster area start: sector {h_cas} (expected {cas_sector})"))
        failed += 1
    
    if h_bank_count == bank_count:
        print(ok(f"Bank count: {h_bank_count}"))
        passed += 1
    else:
        print(warn(f"Bank count: {h_bank_count} (template says {bank_count})"))
        warnings += 1
    
    # ===== TEST 4: Boot sector comparison =====
    if work_data:
        if data[0:512] == work_data[0:512]:
            print(ok("Boot sector: IDENTICAL to working disk"))
            passed += 1
        else:
            diffs = sum(1 for i in range(512) if data[i] != work_data[i])
            print(fail(f"Boot sector: {diffs} bytes differ from working disk"))
            failed += 1
    
    # ===== TEST 5: Status table =====
    status = data[0x200:0x400]
    if status[0] == 0x0F and status[1] == 0x00:
        print(ok(f"Status table: starts with 0x{status[0]:02X}{status[1]:02X}"))
        passed += 1
    else:
        print(fail(f"Status table: starts with 0x{status[0]:02X}{status[1]:02X} (expected 0x0F00)"))
        failed += 1
    
    if work_data:
        if data[0x200:0x400] == work_data[0x200:0x400]:
            print(ok("Status table: IDENTICAL to working disk"))
            passed += 1
        else:
            diffs = sum(1 for i in range(0x200, 0x400) if data[i] != work_data[i])
            print(fail(f"Status table: {diffs} bytes differ from working disk"))
            failed += 1
    
    # ===== TEST 6: FAT =====
    fat_start = 0x400
    fat_size = 1024  # 512 entries × 2 bytes
    
    # Parse FAT chains
    fat_entries = []
    for i in range(512):
        entry = read_u16le(data, fat_start + i * 2)
        fat_entries.append(entry)
    
    # FAT[0] should be 0x8000 (reserved)
    if fat_entries[0] == 0x8000:
        print(ok(f"FAT[0]: 0x{fat_entries[0]:04X} (reserved)"))
        passed += 1
    else:
        print(fail(f"FAT[0]: 0x{fat_entries[0]:04X} (expected 0x8000)"))
        failed += 1
    
    # FAT[1] should be 0x7FFF (OS end-of-chain)
    if fat_entries[1] == 0x7FFF:
        print(ok(f"FAT[1]: 0x{fat_entries[1]:04X} (OS end-of-chain)"))
        passed += 1
    else:
        print(fail(f"FAT[1]: 0x{fat_entries[1]:04X} (expected 0x7FFF = OS end)"))
        failed += 1
    
    # Count FAT chains (bank chains starting from cluster 2+)
    chains = []
    visited = set()
    for start in range(2, 512):
        if start in visited:
            continue
        if fat_entries[start] == 0x7FFF or fat_entries[start] == 0x8080 or fat_entries[start] == 0x0000:
            if fat_entries[start] == 0x7FFF:
                chains.append([start])
                visited.add(start)
            continue
        # Follow chain
        chain = [start]
        visited.add(start)
        current = start
        while fat_entries[current] != 0x7FFF and fat_entries[current] != 0x8080 and fat_entries[current] != 0x0000:
            next_cluster = fat_entries[current]
            if next_cluster >= 512 or next_cluster in visited:
                break
            chain.append(next_cluster)
            visited.add(next_cluster)
            current = next_cluster
        if fat_entries[current] == 0x7FFF:
            chains.append(chain)
    
    if len(chains) >= 1:
        print(ok(f"FAT chains: {len(chains)} bank chain(s) found"))
        passed += 1
        for i, chain in enumerate(chains[:5]):
            if len(chain) <= 8:
                chain_str = '→'.join(str(c) for c in chain) + '→END'
            else:
                chain_str = '→'.join(str(c) for c in chain[:4]) + f'→...→{chain[-1]}→END ({len(chain)} clusters)'
            print(f"       Chain {i}: {chain_str}")
    else:
        print(fail("FAT chains: NO bank chains found! EMAX II requires at least 1 bank!"))
        failed += 1
    
    # FAT comparison with working disk
    if work_data:
        fat_diffs = 0
        for i in range(512):
            w_entry = read_u16le(work_data, fat_start + i * 2)
            n_entry = read_u16le(data, fat_start + i * 2)
            if w_entry != n_entry:
                fat_diffs += 1
        
        if fat_diffs == 0:
            print(ok("FAT: IDENTICAL to working disk"))
            passed += 1
        else:
            print(fail(f"FAT: {fat_diffs} entries differ from working disk"))
            failed += 1
            # Show first 5 differences
            shown = 0
            for i in range(512):
                w_entry = read_u16le(work_data, fat_start + i * 2)
                n_entry = read_u16le(data, fat_start + i * 2)
                if w_entry != n_entry and shown < 5:
                    print(f"       FAT[{i}]: WORK=0x{w_entry:04X} WIZARD=0x{n_entry:04X}")
                    shown += 1
    
    # ===== TEST 7: Catalog =====
    catalog = data[catalog_offset:catalog_offset + 4896]
    
    # Count non-zero 64-byte entries
    catalog_entries = 0
    for i in range(0, 4896, 64):
        entry = catalog[i:i+64]
        if entry != b'\x00' * 64:
            catalog_entries += 1
    
    # Entry 0 should be OS (starts with 00 F0)
    if catalog[0] == 0x00 and catalog[1] == 0xF0:
        print(ok(f"Catalog[0]: OS entry (00 F0...)"))
        passed += 1
    else:
        print(fail(f"Catalog[0]: 0x{catalog[0]:02X}{catalog[1]:02X} (expected 00 F0 = OS)"))
        failed += 1
    
    # Should have at least 1 bank entry (entry 2+ at offset 128+)
    has_bank = False
    for i in range(128, 4896, 64):
        entry = catalog[i:i+64]
        if entry != b'\x00' * 64:
            has_bank = True
            break
    
    if has_bank:
        print(ok(f"Catalog: Has bank entry (total {catalog_entries} non-zero entries)"))
        passed += 1
    else:
        print(fail("Catalog: NO bank entries! EMAX II requires at least 1 bank to boot!"))
        failed += 1
    
    # Catalog comparison
    if work_data:
        work_catalog = work_data[catalog_offset:catalog_offset + 4896]
        if catalog == work_catalog:
            print(ok("Catalog: IDENTICAL to working disk"))
            passed += 1
        else:
            cat_diffs = sum(1 for i in range(4896) if catalog[i] != work_catalog[i])
            print(fail(f"Catalog: {cat_diffs} bytes differ from working disk"))
            failed += 1
    
    # ===== TEST 8: OS Data =====
    os_data = data[os_data_offset:os_data_offset + 128]
    
    # Should start with known OS signature
    os_sig = os_data[:4].hex()
    if os_sig == '110014b8':
        print(ok(f"OS data: Correct signature ({os_sig})"))
        passed += 1
    else:
        print(fail(f"OS data: Wrong signature ({os_sig}), expected 110014b8"))
        failed += 1
    
    # OS not all zeros
    if os_data != b'\x00' * 128:
        print(ok("OS data: Contains data (not empty)"))
        passed += 1
    else:
        print(fail("OS data: ALL ZEROS! No OS loaded!"))
        failed += 1
    
    # OS comparison
    if work_data:
        work_os = work_data[os_data_offset:os_data_offset + min(cluster_size, len(work_data) - os_data_offset)]
        new_os = data[os_data_offset:os_data_offset + min(cluster_size, len(data) - os_data_offset)]
        compare_len = min(len(work_os), len(new_os))
        
        if work_os[:compare_len] == new_os[:compare_len]:
            print(ok(f"OS data: IDENTICAL to working disk ({compare_len:,} bytes)"))
            passed += 1
        else:
            os_diffs = sum(1 for i in range(compare_len) if work_os[i] != new_os[i])
            print(fail(f"OS data: {os_diffs:,} bytes differ from working disk"))
            failed += 1
    
    # ===== TEST 9: Bank data at cluster locations =====
    # Check if clusters referenced by FAT chains actually have data
    if chains:
        first_chain = chains[0]
        first_cluster = first_chain[0]
        bank_data_offset = catalog_offset + first_cluster * cluster_size
        
        if bank_data_offset + 128 <= len(data):
            bank_sample = data[bank_data_offset:bank_data_offset + 128]
            if bank_sample != b'\x00' * 128:
                print(ok(f"Bank data: Cluster {first_cluster} has data at 0x{bank_data_offset:X}"))
                passed += 1
            else:
                print(warn(f"Bank data: Cluster {first_cluster} is ALL ZEROS at 0x{bank_data_offset:X}"))
                warnings += 1
                print(f"       (EMAX II may or may not require actual sample data)")
        else:
            print(warn(f"Bank data: Cluster {first_cluster} offset 0x{bank_data_offset:X} beyond read range"))
            warnings += 1
        
        if work_data and bank_data_offset + 128 <= len(work_data):
            work_bank = work_data[bank_data_offset:bank_data_offset + 128]
            new_bank = data[bank_data_offset:bank_data_offset + 128]
            if work_bank == new_bank:
                print(ok(f"Bank data: IDENTICAL to working disk"))
                passed += 1
            else:
                bank_diffs = sum(1 for i in range(128) if work_bank[i] != new_bank[i])
                print(fail(f"Bank data: {bank_diffs} bytes differ from working disk"))
                failed += 1
    
    # ===== SUMMARY =====
    print(f"\n{'='*60}")
    total = passed + failed + warnings
    print(f"{Colors.BOLD}RESULTS: {passed}/{total} passed, {failed} failed, {warnings} warnings{Colors.END}")
    
    if failed == 0:
        print(f"\n{Colors.OK}{Colors.BOLD}🎉 VERDICT: SHOULD BOOT!{Colors.END}")
    elif failed <= 2:
        print(f"\n{Colors.WARN}{Colors.BOLD}⚠️  VERDICT: MIGHT BOOT (minor issues){Colors.END}")
    else:
        print(f"\n{Colors.FAIL}{Colors.BOLD}🚨 VERDICT: WILL NOT BOOT ({failed} critical failures){Colors.END}")
    
    print()
    return failed == 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 validate-boot.py <image.hda>")
        print("       python3 validate-boot.py /Volumes/ZULUSCI/HD10.hda")
        sys.exit(1)
    
    image = sys.argv[1]
    validate(image)
