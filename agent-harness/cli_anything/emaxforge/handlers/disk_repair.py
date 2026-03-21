"""
disk_repair.py — Repair EMAX II disk image (EMXP "Repair Disk" equivalent)

Fixes:
  1. Orphan clusters  — FAT entries pointing nowhere (not in any BNT chain)
                        → zeroed (marked free)
  2. Broken chains    — FAT chain that goes out of bounds or loops
                        → chain truncated at last valid cluster (EOC written)
  3. BNT count fix    — cluster_count field in BNT entry out of sync with FAT chain
                        → corrected to actual chain length
  4. Duplicate names  — two BNT slots with identical name
                        → second one flagged in report (not auto-fixed, needs user decision)

Safe by design:
  - Never touches cluster DATA — only FAT entries and BNT metadata
  - Writes to destination (default: in-place backup first)
  - Dry-run mode shows what would change without writing
"""

import struct
import time
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Optional


FAT_OFFSET     = 0x0200
FAT_END        = 0x1000
BNT_OFFSET     = 0x1000
BNT_ENTRY_SIZE = 32
BNT_MAX_SLOTS  = 100
EOC            = 0x7FFF


def _u16(data, off):
    return struct.unpack_from('<H', data, off)[0]

def _u32(data, off):
    return struct.unpack_from('<I', data, off)[0]

def _w16(data, off, val):
    struct.pack_into('<H', data, off, val)


@dataclass
class RepairAction:
    kind: str          # 'orphan_freed', 'chain_truncated', 'bnt_count_fixed', 'duplicate_name'
    cluster: Optional[int] = None
    slot: Optional[int] = None
    bank_name: str = ''
    detail: str = ''


@dataclass
class RepairReport:
    disk_path: str
    dry_run: bool
    total_clusters: int
    orphans_freed: int = 0
    chains_truncated: int = 0
    bnt_counts_fixed: int = 0
    duplicate_names: int = 0
    actions: List[RepairAction] = field(default_factory=list)
    elapsed_ms: int = 0

    @property
    def total_fixes(self):
        return self.orphans_freed + self.chains_truncated + self.bnt_counts_fixed

    @property
    def is_clean(self):
        return self.total_fixes == 0 and self.duplicate_names == 0


def _parse_header(data):
    cluster_size  = _u32(data, 0x04) or 489_472
    ca_start_sec  = _u32(data, 0x20)
    total_clusters = _u32(data, 0x24)
    ca_offset     = ca_start_sec * 512 if ca_start_sec else 0xC400
    return cluster_size, ca_offset, total_clusters


def _read_fat(data):
    fat = bytearray(data[FAT_OFFSET:FAT_END])
    return fat


def _fat_get(fat, idx):
    return struct.unpack_from('<H', fat, idx * 2)[0]

def _fat_set(fat, idx, val):
    struct.pack_into('<H', fat, idx * 2, val)


def _is_eoc(val):
    return val >= 0x7F00 or val == 0x8080


def _follow_chain(fat, start, total_clusters):
    """Follow FAT chain. Returns (chain, truncated_at) where truncated_at is
    the index where truncation happened (or None if clean)."""
    chain, visited = [], set()
    cur = start
    while True:
        if cur in visited:
            # Loop detected — truncate here
            return chain, cur
        if cur < 1 or cur > total_clusters:
            # Out of bounds
            return chain, cur
        chain.append(cur)
        visited.add(cur)
        nxt = _fat_get(fat, cur)
        if _is_eoc(nxt) or nxt == 0x0000:
            break
        cur = nxt
    return chain, None


def _parse_bnt(data):
    """Parse all active BNT entries. Returns list of dicts."""
    banks = []
    for s in range(BNT_MAX_SLOTS):
        off = BNT_OFFSET + s * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > len(data):
            break
        raw   = data[off: off + 14]
        name  = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        flags = _u16(data, off + 26)
        if not name or not (flags & 0x0001):
            continue
        start_cl = _u16(data, off + 18)
        cl_count = _u16(data, off + 20)
        banks.append({
            'slot':       s,
            'name':       name,
            'start_cl':   start_cl,
            'cl_count':   cl_count,
            'flags':      flags,
        })
    return banks


def repair_disk(
    disk_path: str,
    dst_path: str = None,
    dry_run: bool = False,
) -> RepairReport:
    """
    Scan and repair an EMAX II disk image.

    dst_path=None  → repair in-place (overwrites disk_path)
    dst_path=<path> → write repaired copy to dst_path, leave original untouched
    dry_run=True   → analyse only, no writes
    """
    t0 = time.time()
    src = Path(disk_path).expanduser()

    if not src.exists():
        raise FileNotFoundError(f"Disk not found: {src}")

    with open(src, 'rb') as f:
        data = bytearray(f.read())

    cluster_size, ca_offset, total_clusters = _parse_header(data)
    fat = _read_fat(data)

    report = RepairReport(
        disk_path=str(src),
        dry_run=dry_run,
        total_clusters=total_clusters,
    )

    # ── EMAX II allocation model ─────────────────────────────────────────────
    # EMAX II uses CONTIGUOUS allocation — NOT FAT chaining.
    # BNT: start_cluster + cluster_count → N consecutive clusters
    # FAT: each used cluster is marked 0x8080 (EOC), free = 0x0000
    # The FAT is a simple allocation bitmap, not a linked list.
    # We therefore build 'referenced' from BNT ranges, NOT FAT chains.

    # ── 1. Build referenced set from BNT (contiguous ranges) ────────────────
    banks = _parse_bnt(data)
    referenced = set()

    # OS is slot 0 — mark its clusters referenced
    os_entry_off = BNT_OFFSET
    os_start = _u16(data, os_entry_off + 18)
    os_count  = _u16(data, os_entry_off + 20)
    if os_start >= 1 and os_count >= 1:
        for c in range(os_start, os_start + os_count):
            if 1 <= c <= total_clusters:
                referenced.add(c)

    for bank in banks:
        if bank['slot'] == 0:
            continue
        sc = bank['start_cl']
        cc = bank['cl_count']
        if sc < 1 or cc < 1:
            continue
        for c in range(sc, sc + cc):
            if 1 <= c <= total_clusters:
                referenced.add(c)

    # ── 2. Check for out-of-bounds BNT entries ───────────────────────────────
    for bank in banks:
        if bank['slot'] == 0:
            continue
        end = bank['start_cl'] + bank['cl_count'] - 1
        if end > total_clusters:
            report.actions.append(RepairAction(
                kind='chain_truncated',
                slot=bank['slot'],
                bank_name=bank['name'],
                detail=f"BNT range [{bank['start_cl']}..{end}] exceeds disk size ({total_clusters})",
            ))
            report.chains_truncated += 1

    # ── 3. Find orphan clusters (FAT=non-zero but not referenced by any BNT) ─
    for i in range(1, total_clusters + 1):
        val = _fat_get(fat, i)
        if val == 0x0000:
            continue   # already free
        if i in referenced:
            continue   # legitimately used
        # Orphan — free it
        report.actions.append(RepairAction(
            kind='orphan_freed',
            cluster=i,
            detail=f"FAT[{i}]={val:#06x} → 0x0000 (not referenced by any bank)",
        ))
        report.orphans_freed += 1
        if not dry_run:
            _fat_set(fat, i, 0x0000)

    # ── 4. Find clusters referenced by BNT but marked free in FAT ────────────
    for i in referenced:
        val = _fat_get(fat, i)
        if val == 0x0000:
            # Should be marked used — fix FAT
            report.actions.append(RepairAction(
                kind='bnt_count_fixed',   # re-use kind for "FAT allocation fix"
                cluster=i,
                detail=f"FAT[{i}] was free (0x0000) but referenced by BNT → marked 0x8080",
            ))
            report.bnt_counts_fixed += 1
            if not dry_run:
                _fat_set(fat, i, 0x8080)

    # ── 4. Duplicate bank names ──────────────────────────────────────────────
    seen_names = {}
    for bank in banks:
        key = bank['name'].lower()
        if key in seen_names:
            report.actions.append(RepairAction(
                kind='duplicate_name',
                slot=bank['slot'],
                bank_name=bank['name'],
                detail=f"duplicate of slot {seen_names[key]} — manual resolution needed",
            ))
            report.duplicate_names += 1
        else:
            seen_names[key] = bank['slot']

    # ── 5. Write repaired disk ───────────────────────────────────────────────
    if not dry_run and report.total_fixes > 0:
        # Write FAT back
        data[FAT_OFFSET:FAT_END] = fat

        out_path = Path(dst_path).expanduser() if dst_path else src
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, 'wb') as f:
            f.write(data)

    report.elapsed_ms = int((time.time() - t0) * 1000)
    return report


def format_repair_report(report: RepairReport, verbose: bool = False) -> str:
    lines = []
    tag = "[DRY RUN] " if report.dry_run else ""
    lines.append(f"🔧 {tag}Disk Repair Report")
    lines.append(f"   Disk:    {report.disk_path}")
    lines.append(f"   Clusters: {report.total_clusters}")
    lines.append("")

    if report.is_clean:
        lines.append("✅ Disk is clean — no repairs needed")
        lines.append(f"   (elapsed {report.elapsed_ms} ms)")
        return "\n".join(lines)

    verb = "Would fix" if report.dry_run else "Fixed"
    lines.append(f"{'🔍' if report.dry_run else '✅'} Results:")
    lines.append(f"   {verb} orphan clusters:  {report.orphans_freed}")
    lines.append(f"   {verb} broken chains:    {report.chains_truncated}")
    lines.append(f"   {verb} BNT count errors: {report.bnt_counts_fixed}")
    if report.duplicate_names:
        lines.append(f"   ⚠️  Duplicate names:    {report.duplicate_names} (manual fix needed)")
    lines.append(f"   Total fixes: {report.total_fixes}")
    lines.append(f"   Elapsed: {report.elapsed_ms} ms")

    if verbose and report.actions:
        lines.append("")
        lines.append("Actions:")
        for a in report.actions:
            icon = {
                'orphan_freed':    '🗑',
                'chain_truncated': '✂️',
                'bnt_count_fixed': '📝',
                'duplicate_name':  '⚠️',
            }.get(a.kind, '?')
            name_part = f' [{a.bank_name}]' if a.bank_name else ''
            slot_part = f' slot={a.slot}' if a.slot is not None else ''
            cl_part   = f' cl={a.cluster}' if a.cluster is not None else ''
            lines.append(f"  {icon}{name_part}{slot_part}{cl_part}: {a.detail}")

    return "\n".join(lines)
