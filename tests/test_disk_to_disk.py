"""Test disk-to-disk bank copy."""
import struct
from pathlib import Path
import tempfile
import sys

sys.path.insert(0, str(Path(__file__).parent.parent / "agent-harness"))

from cli_anything.emaxforge.core.bank import copy_bank, delete_bank, list_banks
from cli_anything.emaxforge.core.disk import create_disk

IMAGES = Path.home() / "Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/EMXP/Images"
HD10 = IMAGES / "HD10.EZ2"

def test_copy_bank():
    with tempfile.TemporaryDirectory() as tmpdir:
        dst = Path(tmpdir) / "test_copy.hda"
        create_disk(239, 1, str(dst), include_os=True)
        result = copy_bank(str(HD10), 1, str(dst))

        assert 'STEEL' in result['bank_name'].upper(), f"Wrong name: {result['bank_name']}"
        assert result['clusters_used'] == 5, f"Wrong cluster count: {result['clusters_used']}"
        assert result['preset_count'] == 51, f"Wrong preset count: {result['preset_count']}"

        # Verify BNT
        banks = list_banks(str(dst))
        steel = next((b for b in banks['banks'] if 'STEEL' in b['name'].upper()), None)
        assert steel is not None, "STEEL DRUMS not found in destination BNT"

        # Verify byte-for-byte identical cluster data
        with open(HD10, 'rb') as f:
            f.seek(0x04); cs = struct.unpack('<I', f.read(4))[0]
            f.seek(0x20); ca = struct.unpack('<I', f.read(4))[0] * 512
            f.seek(ca + (2-1)*cs)
            src_data = f.read(cs * 5)

        dst_cluster = steel['cluster']
        with open(dst, 'rb') as f:
            f.seek(0x04); cs2 = struct.unpack('<I', f.read(4))[0]
            f.seek(0x20); ca2 = struct.unpack('<I', f.read(4))[0] * 512
            f.seek(ca2 + (int(dst_cluster)-1)*cs2)
            dst_data = f.read(cs2 * 5)

        assert src_data == dst_data, f"Bank data mismatch! First diff at byte {next(i for i,(a,b) in enumerate(zip(src_data,dst_data)) if a!=b)}"
        print(f"✅ test_copy_bank PASSED — '{result['bank_name']}' copied byte-for-byte")

def test_delete_bank():
    with tempfile.TemporaryDirectory() as tmpdir:
        dst = Path(tmpdir) / "test_delete.hda"
        create_disk(239, 1, str(dst), include_os=True)
        copy_result = copy_bank(str(HD10), 1, str(dst))

        banks_before = list_banks(str(dst))['count']
        copied_slot = copy_result['dst_slot']
        result = delete_bank(str(dst), copied_slot)
        banks_after = list_banks(str(dst))['count']

        assert banks_after < banks_before, "Bank count should decrease"
        assert result['clusters_freed'] > 0
        print(f"✅ test_delete_bank PASSED — freed {result['clusters_freed']} clusters")

def test_copy_multiple():
    """Copy 5 banks from HD10 to new disk."""
    with tempfile.TemporaryDirectory() as tmpdir:
        dst = Path(tmpdir) / "test_multi.hda"
        create_disk(239, 1, str(dst), include_os=True)

        banks = list_banks(str(HD10))['banks']
        data_banks = [b for b in banks if b['slot'] != 0][:5]

        for b in data_banks:
            r = copy_bank(str(HD10), b['slot'], str(dst))
            print(f"  Copied slot {b['slot']}: '{r['bank_name']}' → dst slot {r['dst_slot']}")

        result_banks = list_banks(str(dst))
        assert result_banks['count'] >= len(data_banks) + 1  # +1 for OS
        print(f"✅ test_copy_multiple PASSED — {len(data_banks)} banks copied")

if __name__ == '__main__':
    print("Running disk-to-disk copy tests...\n")
    test_copy_bank()
    test_delete_bank()
    test_copy_multiple()
    print("\n🎉 ALL TESTS PASSED")
