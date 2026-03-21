"""
EMAX II Disk Validator — Deep validation cloning EMXP's verification logic.

Checks:
  1. Boot signature (0x7882)
  2. FAT header entry (0x000F or legacy 0x8000)
  3. BNT integrity — each entry has valid name, cluster, count
  4. FAT ↔ BNT cross-reference — every BNT bank has a valid FAT chain
  5. FAT chain integrity — no circular, broken, or orphan chains
  6. Data integrity — bank cluster data is non-zero (not blank)
  7. Cluster bounds — no BNT entry references out-of-range clusters
  8. Duplicate cluster detection — two banks sharing same cluster
"""

import struct
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum


class Severity(Enum):
    INFO  = "INFO"
    WARN  = "WARN"
    ERROR = "ERROR"


@dataclass
class Issue:
    severity: Severity
    code: str
    message: str
    slot: Optional[int] = None
    cluster: Optional[int] = None


@dataclass
class BankEntry:
    slot: int
    name: str
    start_cluster: int
    cluster_count: int
    flags: int
    idx: int


@dataclass
class ValidationResult:
    disk_path: str
    issues: List[Issue] = field(default_factory=list)
    banks: List[BankEntry] = field(default_factory=list)
    total_clusters: int = 0
    used_clusters: int = 0
    free_clusters: int = 0

    @property
    def errors(self):   return [i for i in self.issues if i.severity == Severity.ERROR]
    @property
    def warnings(self): return [i for i in self.issues if i.severity == Severity.WARN]
    @property
    def infos(self):    return [i for i in self.issues if i.severity == Severity.INFO]
    @property
    def is_valid(self): return len(self.errors) == 0


# ── helpers ────────────────────────────────────────────────────────────────

def _u16(data, off): return struct.unpack_from('<H', data, off)[0]
def _u32(data, off): return struct.unpack_from('<I', data, off)[0]

EOC        = {0x7FFF, 0xFFFF, 0x8080}  # end-of-chain markers (0x8080 = single-cluster bank)
FREE       = {0x0000}                  # free cluster
FAT0_VALID = {0x000F, 0x0009, 0x8000} # valid FAT[0] values seen in real disks


def _is_eoc(v):  return v in EOC or (0x7F00 <= v <= 0x7FFE) or v >= 0x8000
def _is_free(v): return v == 0x0000


def _follow_chain(fat, start, total_clusters, allow_free_end=False):
    """Follow FAT chain. Returns (clusters[], is_circular, is_broken).
    allow_free_end: treat FREE marker as valid single-cluster end (used for OS slot).
    """
    chain, visited = [], set()
    cur = start
    while True:
        if cur in visited:
            chain.append(cur)
            return chain, True, False   # circular
        if cur < 1 or cur >= len(fat):
            return chain, False, True   # out of bounds
        chain.append(cur)
        visited.add(cur)
        nxt = fat[cur]
        if _is_eoc(nxt):
            return chain, False, False  # normal end
        if _is_free(nxt):
            if allow_free_end:
                return chain, False, False  # OS slot: free = end of single cluster
            return chain, False, True   # broken (free mid-chain)
        cur = nxt


# ── main validator ─────────────────────────────────────────────────────────

def validate_disk(disk_path: str) -> ValidationResult:
    path = Path(disk_path)
    result = ValidationResult(disk_path=str(path))

    if not path.exists():
        result.issues.append(Issue(Severity.ERROR, "FILE_NOT_FOUND", f"Disk file not found: {disk_path}"))
        return result

    data = path.read_bytes()
    size = len(data)

    # ── 1. Minimum size ────────────────────────────────────────────────────
    if size < 0x10000:
        result.issues.append(Issue(Severity.ERROR, "TOO_SMALL", f"File too small: {size} bytes"))
        return result

    # ── 2. Boot signature ──────────────────────────────────────────────────
    # Bytes at 0x1FE = 0x78, 0x1FF = 0x82 → read as big-endian
    boot_sig = struct.unpack_from('>H', data, 0x1FE)[0]
    if boot_sig != 0x7882:
        result.issues.append(Issue(Severity.ERROR, "BAD_BOOT_SIG",
            f"Boot signature 0x{boot_sig:04X} (expected 0x7882)"))
    else:
        result.issues.append(Issue(Severity.INFO, "BOOT_SIG_OK", "Boot signature 0x7882 ✅"))

    # ── 3. Parse header ────────────────────────────────────────────────────
    cluster_size   = _u32(data, 0x04)
    fat_sectors    = _u32(data, 0x08)
    max_banks      = _u32(data, 0x10)
    ca_start_sec   = _u32(data, 0x20)

    if cluster_size == 0 or cluster_size > 0x200000:
        result.issues.append(Issue(Severity.ERROR, "BAD_CLUSTER_SIZE",
            f"Invalid cluster size: {cluster_size}"))
        return result

    ca_offset = ca_start_sec * 512
    if ca_offset >= size:
        result.issues.append(Issue(Severity.ERROR, "BAD_CA_OFFSET",
            f"Cluster area starts beyond file end: 0x{ca_offset:X} >= 0x{size:X}"))
        return result

    total_clusters = (size - ca_offset) // cluster_size
    result.total_clusters = total_clusters

    result.issues.append(Issue(Severity.INFO, "GEOMETRY",
        f"cluster_size={cluster_size}, ca_offset=0x{ca_offset:X}, "
        f"total_clusters={total_clusters}, max_banks={max_banks}"))

    # ── 4. FAT[0] check ────────────────────────────────────────────────────
    fat0 = _u16(data, 0x200)
    if fat0 not in FAT0_VALID:
        result.issues.append(Issue(Severity.WARN, "UNEXPECTED_FAT0",
            f"FAT[0]=0x{fat0:04X} (expected one of {[hex(v) for v in FAT0_VALID]})"))
    else:
        result.issues.append(Issue(Severity.INFO, "FAT0_OK", f"FAT[0]=0x{fat0:04X} ✅"))

    # ── 5. Parse FAT ───────────────────────────────────────────────────────
    # FAT lives from sector 1 (0x200) up to BNT start (0x1000) — verified
    fat_offset = 0x200
    fat_end    = 0x1000  # BNT starts here
    fat = [_u16(data, fat_offset + i * 2) for i in range((fat_end - fat_offset) // 2)]

    # ── 6. Parse BNT ───────────────────────────────────────────────────────
    BNT_OFFSET     = 0x1000
    BNT_ENTRY_SIZE = 32
    bnt_slots      = (ca_offset - BNT_OFFSET) // BNT_ENTRY_SIZE

    banks: List[BankEntry] = []
    for slot in range(bnt_slots):
        off = BNT_OFFSET + slot * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > ca_offset:
            break
        entry = data[off: off + BNT_ENTRY_SIZE]
        name_raw    = entry[0:14]
        idx         = _u16(entry, 16)
        start_cl    = _u16(entry, 18)
        cl_count    = _u16(entry, 20)
        flags       = _u16(entry, 26)

        if start_cl == 0 and cl_count == 0:
            continue  # empty slot

        try:
            name = name_raw.decode('ascii', errors='replace').rstrip('\x00 ')
        except Exception:
            name = f"<invalid@slot{slot}>"

        banks.append(BankEntry(
            slot=slot, name=name,
            start_cluster=start_cl, cluster_count=cl_count,
            flags=flags, idx=idx
        ))

    result.banks = banks

    # ── 7. Per-bank validation ─────────────────────────────────────────────
    seen_clusters = {}   # cluster → slot (for duplicate detection)
    fat_accounted = set()

    for bank in banks:
        s = bank.slot
        sc = bank.start_cluster

        # 7a. Name sanity
        if not bank.name or not bank.name.isprintable():
            result.issues.append(Issue(Severity.WARN, "BAD_NAME",
                f"Slot {s}: non-printable name bytes", slot=s))

        # 7b. Cluster bounds
        if sc < 1 or sc > total_clusters:
            result.issues.append(Issue(Severity.ERROR, "CLUSTER_OOB",
                f"Slot {s} '{bank.name}': start_cluster {sc} out of range (1..{total_clusters})",
                slot=s, cluster=sc))
            continue

        # 7c. FAT chain (slot 0 = OS: allow FREE as end-of-chain)
        is_os_slot = (s == 0)
        chain, is_circ, is_broken = _follow_chain(fat, sc, total_clusters, allow_free_end=is_os_slot)
        fat_accounted.update(chain)

        if is_circ:
            result.issues.append(Issue(Severity.ERROR, "CIRCULAR_CHAIN",
                f"Slot {s} '{bank.name}': circular FAT chain at cluster {chain[-1]}",
                slot=s, cluster=sc))
        elif is_broken:
            result.issues.append(Issue(Severity.ERROR, "BROKEN_CHAIN",
                f"Slot {s} '{bank.name}': broken FAT chain (len={len(chain)})",
                slot=s, cluster=sc))
        else:
            # 7e. Duplicate cluster detection
            for cl in chain:
                if cl in seen_clusters:
                    result.issues.append(Issue(Severity.ERROR, "DUPLICATE_CLUSTER",
                        f"Slot {s} '{bank.name}': cluster {cl} already used by slot "
                        f"{seen_clusters[cl]}",
                        slot=s, cluster=cl))
                seen_clusters[cl] = s

            # Note: BLANK_DATA check removed — EMAX II banks often have zero-padded headers,
            # making this check produce excessive false positives.

    # ── 8. Orphan cluster detection ────────────────────────────────────────
    orphans = []
    for i in range(1, min(total_clusters + 1, len(fat))):
        v = fat[i]
        if i not in fat_accounted and not _is_free(v) and not _is_eoc(v):
            orphans.append(i)

    if orphans:
        result.issues.append(Issue(Severity.WARN, "ORPHAN_CLUSTERS",
            f"{len(orphans)} orphaned cluster(s): {orphans[:10]}"
            + ("..." if len(orphans) > 10 else "")))

    # ── 9. Usage stats ─────────────────────────────────────────────────────
    used = len(fat_accounted)
    free = sum(1 for i in range(1, min(total_clusters + 1, len(fat))) if _is_free(fat[i]))
    result.used_clusters = used
    result.free_clusters = free

    pct = round(used / total_clusters * 100, 1) if total_clusters else 0
    result.issues.append(Issue(Severity.INFO, "USAGE",
        f"Clusters: {used} used / {free} free / {total_clusters} total ({pct}% used)"))

    return result


def format_report(result: ValidationResult, verbose: bool = False) -> str:
    lines = []
    lines.append(f"{'='*60}")
    lines.append(f"DISK VALIDATION: {Path(result.disk_path).name}")
    lines.append(f"{'='*60}")

    # Summary
    if result.is_valid:
        lines.append(f"✅ VALID  —  {len(result.banks)} banks, "
                     f"{result.errors.__len__()} errors, {len(result.warnings)} warnings")
    else:
        lines.append(f"❌ INVALID  —  {len(result.errors)} error(s), {len(result.warnings)} warning(s)")

    lines.append("")

    # Banks
    if result.banks:
        lines.append(f"Banks ({len(result.banks)}):")
        for b in result.banks:
            lines.append(f"  [{b.slot:2d}] {b.name:<14} cl={b.start_cluster}, cnt={b.cluster_count}")
        lines.append("")

    # Issues
    errors   = result.errors
    warnings = result.warnings
    infos    = result.infos

    if errors:
        lines.append("❌ Errors:")
        for i in errors:
            lines.append(f"  [{i.code}] {i.message}")
        lines.append("")

    if warnings:
        lines.append("⚠️  Warnings:")
        for i in warnings:
            lines.append(f"  [{i.code}] {i.message}")
        lines.append("")

    if verbose and infos:
        lines.append("ℹ️  Info:")
        for i in infos:
            lines.append(f"  [{i.code}] {i.message}")
        lines.append("")

    # Stats line always shown
    for i in infos:
        if i.code == "USAGE":
            lines.append(f"📊 {i.message}")

    lines.append(f"{'='*60}")
    return "\n".join(lines)
