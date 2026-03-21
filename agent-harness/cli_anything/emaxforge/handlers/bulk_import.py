"""
bulk_import.py — Bulk import .EB2 banks from a directory or glob pattern.

Features:
- Import all EB2s from a directory (recursive optional)
- Skip banks already present on disk (--skip-existing)
- Stop gracefully when disk is full
- Progress bar with bank names
- Dry-run mode (show what would be imported)
- JSON output for machine use
- Sort order: alphabetical or by file size
"""

import fnmatch
import glob
import struct
import time
from pathlib import Path
from typing import List, Optional


# ── Disk layout constants ────────────────────────────────────────────────────
BNT_OFFSET   = 0x1000
FAT_OFFSET   = 0x0200
FAT_END      = 0x1000
BNT_MAX_SLOTS = 100


def _u16(data, off):
    return struct.unpack_from('<H', data, off)[0]


def _u32(data, off):
    return struct.unpack_from('<I', data, off)[0]


def _read_disk_state(disk_path: str) -> dict:
    """Read current BNT + FAT state from disk. Returns info needed for import decisions."""
    with open(disk_path, 'rb') as f:
        data = f.read()

    cluster_size = _u32(data, 0x04) or 489_472
    ca_start_sec = _u32(data, 0x20)
    total_clusters = _u32(data, 0x24)
    ca_offset = ca_start_sec * 512 if ca_start_sec else 0xC400

    # Parse FAT — count free clusters
    fat = [_u16(data, FAT_OFFSET + i * 2) for i in range((FAT_END - FAT_OFFSET) // 2)]
    free_clusters = sum(1 for v in fat[1:total_clusters + 1] if v == 0x0000)

    # Parse BNT — collect existing bank names + find free slots
    existing_names = {}   # name (lower) → slot
    free_slots = []
    for s in range(BNT_MAX_SLOTS):
        off = BNT_OFFSET + s * 32
        if off + 32 > len(data):
            break
        raw = data[off: off + 14]
        name = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        flags = _u16(data, off + 26)
        if name and flags & 0x0001:
            existing_names[name.lower()] = s
        elif not name or flags == 0:
            free_slots.append(s)

    return {
        'cluster_size':   cluster_size,
        'total_clusters': total_clusters,
        'free_clusters':  free_clusters,
        'ca_offset':      ca_offset,
        'existing_names': existing_names,
        'free_slots':     free_slots,
        'free_mb':        free_clusters * cluster_size / (1024 * 1024),
    }


def _eb2_name_from_path(path: Path) -> str:
    """Derive EMAX II bank name from EB2 filename (max 14 chars, strip slot prefix)."""
    import re
    stem = path.stem
    stem = re.sub(r'^slot\d+_', '', stem, flags=re.IGNORECASE)
    name = stem.replace('_', ' ')[:14]
    return name


def _eb2_clusters_needed(eb2_path: Path, cluster_size: int) -> int:
    """How many clusters does this EB2 need?"""
    size = eb2_path.stat().st_size
    return max(1, (size + cluster_size - 1) // cluster_size)


def collect_eb2_files(source: str, recursive: bool = False) -> List[Path]:
    """Collect all .EB2 files from a directory or glob pattern."""
    p = Path(source).expanduser()

    if p.is_dir():
        pattern = '**/*.EB2' if recursive else '*.EB2'
        files = sorted(p.glob(pattern), key=lambda f: f.name.lower())
        # Also catch lowercase .eb2
        files += sorted(p.glob('**/*.eb2' if recursive else '*.eb2'),
                        key=lambda f: f.name.lower())
        # Deduplicate
        seen = set()
        result = []
        for f in files:
            if f not in seen:
                seen.add(f)
                result.append(f)
        return result
    else:
        # Treat as glob
        return sorted([Path(f) for f in glob.glob(source, recursive=recursive)],
                      key=lambda f: f.name.lower())


def bulk_import(
    disk_path: str,
    source: str,
    recursive: bool = False,
    skip_existing: bool = True,
    dry_run: bool = False,
    progress: bool = True,
    sort_by: str = 'name',        # 'name' | 'size'
    limit: Optional[int] = None,
) -> dict:
    """
    Bulk import .EB2 banks from a directory or glob into a disk image.

    Returns:
      imported: int      — banks successfully imported
      skipped:  int      — skipped (already on disk)
      failed:   int      — errors
      disk_full: bool    — stopped early due to disk full
      results:  list     — per-bank detail
      elapsed_ms: int
    """
    t0 = time.time()

    from cli_anything.emaxforge.core.bank import import_bank

    # 1. Collect files
    files = collect_eb2_files(source, recursive=recursive)
    if not files:
        return {'success': False, 'error': f'No .EB2 files found in: {source}'}

    # 2. Sort
    if sort_by == 'size':
        files.sort(key=lambda f: f.stat().st_size)

    # 3. Apply limit
    if limit:
        files = files[:limit]

    # 4. Read current disk state
    state = _read_disk_state(disk_path)

    # 5. Build import plan
    plan = []
    for f in files:
        name = _eb2_name_from_path(f)
        clusters_needed = _eb2_clusters_needed(f, state['cluster_size'])
        already_exists = name.lower() in state['existing_names']
        plan.append({
            'path': f,
            'name': name,
            'clusters': clusters_needed,
            'size_mb': f.stat().st_size / (1024 * 1024),
            'already_exists': already_exists,
        })

    if dry_run:
        to_import = [p for p in plan if not (skip_existing and p['already_exists'])]
        total_clusters = sum(p['clusters'] for p in to_import)
        return {
            'dry_run': True,
            'total_files': len(files),
            'to_import': len(to_import),
            'to_skip': len(plan) - len(to_import),
            'clusters_needed': total_clusters,
            'clusters_free': state['free_clusters'],
            'will_fit': total_clusters <= state['free_clusters'],
            'plan': [{'name': p['name'], 'file': str(p['path']),
                      'size_mb': round(p['size_mb'], 2),
                      'clusters': p['clusters'],
                      'skip_reason': 'exists' if p['already_exists'] else None}
                     for p in plan],
        }

    # 6. Execute import
    results = []
    imported = skipped = failed = 0
    disk_full = False
    free_remaining = state['free_clusters']

    for i, item in enumerate(plan):
        # Skip existing?
        if skip_existing and item['already_exists']:
            results.append({
                'file': item['path'].name,
                'name': item['name'],
                'status': 'skipped',
                'reason': 'already on disk',
            })
            skipped += 1
            if progress:
                _print_progress(i + 1, len(plan), item['name'], 'SKIP')
            continue

        # Disk full check
        if item['clusters'] > free_remaining:
            results.append({
                'file': item['path'].name,
                'name': item['name'],
                'status': 'skipped',
                'reason': f'disk full ({free_remaining} clusters free, need {item["clusters"]})',
            })
            disk_full = True
            if progress:
                _print_progress(i + 1, len(plan), item['name'], 'FULL')
            # Don't break — continue to report remaining as skipped
            continue

        # Import
        try:
            result = import_bank(disk_path=disk_path, bank_path=str(item['path']))
            if result.get('success') or result.get('slot') is not None:
                results.append({
                    'file': item['path'].name,
                    'name': item['name'],
                    'slot': result.get('slot'),
                    'status': 'imported',
                })
                imported += 1
                free_remaining -= item['clusters']
                if progress:
                    _print_progress(i + 1, len(plan), item['name'], 'OK')
            else:
                results.append({
                    'file': item['path'].name,
                    'name': item['name'],
                    'status': 'error',
                    'error': result.get('error', 'unknown'),
                })
                failed += 1
                if progress:
                    _print_progress(i + 1, len(plan), item['name'], 'ERR')
        except Exception as e:
            results.append({
                'file': item['path'].name,
                'name': item['name'],
                'status': 'error',
                'error': str(e),
            })
            failed += 1
            if progress:
                _print_progress(i + 1, len(plan), item['name'], 'ERR')

    elapsed = int((time.time() - t0) * 1000)

    return {
        'success': True,
        'total': len(plan),
        'imported': imported,
        'skipped': skipped,
        'failed': failed,
        'disk_full': disk_full,
        'elapsed_ms': elapsed,
        'results': results,
    }


def _print_progress(current, total, name, status):
    """Print single-line progress update."""
    pct = int(current * 100 / total)
    status_icon = {'OK': '✅', 'SKIP': '⏭', 'FULL': '💾', 'ERR': '❌'}.get(status, '?')
    # Truncate name to 14 chars for alignment
    name_disp = name[:14].ljust(14)
    print(f"  [{current:3d}/{total}] {pct:3d}%  {status_icon} {name_disp}", flush=True)
