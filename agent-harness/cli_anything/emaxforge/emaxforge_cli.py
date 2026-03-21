"""
CLI-Anything EmaxForge - Command-line interface for EMAX II disk management

Commands:
- create-boot-disk: Create bootable EMAX II HD image (from template)
- create-floppy:    Create blank Gotek/HFE floppy image
- create-disk:      Create new EMAX II disk image (legacy alias)
- import-bank:      Import .EB2 bank into disk
- list-banks:       List banks on disk
- list-images:      List all disk images in a directory
- verify-boot:      Verify boot disk structure
- verify-disk:      Verify disk structure (alias)
- export-bank:      Export bank from disk
- repl:             Interactive REPL mode
"""

import click
import json
import sys
from pathlib import Path

from cli_anything.emaxforge.core.disk import create_disk, verify_disk
from cli_anything.emaxforge.core.bank import import_bank, list_banks, export_bank
from cli_anything.emaxforge.core.boot_creator import create_boot_disk, verify_boot_disk, list_images as _list_images
from cli_anything.emaxforge.core.floppy_manager import create_floppy, list_floppies, convert_hfe_to_img
from cli_anything.emaxforge.handlers.audio_converter import AudioConverter
from cli_anything.emaxforge.handlers.batch_ops import BatchOperations
from cli_anything.emaxforge.handlers.zuluscsi_config import ZuluSCSIConfig
from cli_anything.emaxforge.handlers.catalog import CatalogParser
from cli_anything.emaxforge.handlers.bank_templates import BankTemplates
from cli_anything.emaxforge.handlers.fat_analyzer import FATAnalyzer
from cli_anything.emaxforge.handlers.disk_clone import clone_disk
from cli_anything.emaxforge.handlers.disk_validator import validate_disk
from cli_anything.emaxforge.handlers.bulk_import import bulk_import, collect_eb2_files
from cli_anything.emaxforge.handlers.bank_mover import move_bank


@click.group()
@click.version_option(version="0.1.0")
def cli():
    """EmaxForge - CLI for EMAX II disk management"""
    pass


@cli.command()
@click.option('--size', type=click.Choice(['96', '239', '481', '633', '962']), 
              default='239', help='Disk size in MB')
@click.option('--scsi-id', type=int, default=1, help='SCSI ID (1=boot, 2+=data)')
@click.option('--output', type=click.Path(), required=True, help='Output .hda file path')
@click.option('--os/--no-os', default=True, help='Include EMAX II OS (boot disk)')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def create_disk_cmd(size, scsi_id, output, os, output_json):
    """Create new EMAX II disk image"""
    try:
        result = create_disk(
            size_mb=int(size),
            scsi_id=scsi_id,
            output_path=output,
            include_os=os
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Created: {result['disk_path']}")
            click.echo(f"   Size: {result['size_mb']} MB")
            click.echo(f"   SCSI ID: {result['scsi_id']}")
            click.echo(f"   OS: {'Yes' if result['has_os'] else 'No'}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--disk', type=click.Path(exists=True), required=True, help='Disk .hda file')
@click.option('--bank', type=click.Path(exists=True), required=True, help='Bank .EB2 file')
@click.option('--slot', type=int, help='Target slot (default: auto)')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def import_bank_cmd(disk, bank, slot, output_json):
    """Import .EB2 bank into disk"""
    try:
        result = import_bank(
            disk_path=disk,
            bank_path=bank,
            slot=slot
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Imported: {result['bank_name']}")
            click.echo(f"   Slot: {result['slot']}")
            click.echo(f"   Cluster: {result['cluster']}")
            click.echo(f"   Size: {result['size_bytes']} bytes")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--disk', type=click.Path(exists=True), required=True, help='Disk .hda file')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def list_banks_cmd(disk, output_json):
    """List banks on disk"""
    try:
        result = list_banks(disk_path=disk)
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"📀 Disk: {result['disk_path']}")
            click.echo(f"   Banks: {result['count']}")
            click.echo()
            for bank in result['banks']:
                click.echo(f"  [{bank['slot']}] {bank['name']}")
                click.echo(f"       Cluster: {bank['cluster']}, Presets: {bank['presets']}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--disk', type=click.Path(exists=True), required=True, help='Disk .hda file')
@click.option('--verbose', '-v', is_flag=True, help='Show all info messages')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def verify_disk_cmd(disk, verbose, output_json):
    """Deep-validate disk structure (boot sig, FAT, BNT, chains, duplicates, orphans)"""
    from cli_anything.emaxforge.handlers.disk_validator import validate_disk, format_report, Severity
    try:
        result = validate_disk(disk_path=disk)

        if output_json:
            import dataclasses
            out = {
                "disk_path": result.disk_path,
                "valid": result.is_valid,
                "total_clusters": result.total_clusters,
                "used_clusters": result.used_clusters,
                "free_clusters": result.free_clusters,
                "banks": [
                    {"slot": b.slot, "name": b.name,
                     "start_cluster": b.start_cluster, "cluster_count": b.cluster_count}
                    for b in result.banks
                ],
                "errors":   [{"code": i.code, "message": i.message, "slot": i.slot} for i in result.errors],
                "warnings": [{"code": i.code, "message": i.message, "slot": i.slot} for i in result.warnings],
            }
            click.echo(json.dumps(out, indent=2))
        else:
            click.echo(format_report(result, verbose=verbose))

        if not result.is_valid:
            sys.exit(1)
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("clone-disk")
@click.option('--src', 'src_path', type=click.Path(exists=True), required=True,
              help='Source disk (.hda / .EZ2)')
@click.option('--dst', 'dst_path', type=click.Path(), required=True,
              help='Destination path for the cloned disk')
@click.option('--banks-only', is_flag=True, default=False,
              help='Copy banks only (skip OS cluster) — creates a data-disk clone')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON result')
def clone_disk_cmd(src_path, dst_path, banks_only, output_json):
    """Clone a disk image bit-for-bit (EMXP Clone Disk equivalent).

    Full clone:      identical byte-for-byte copy of the entire disk.
    --banks-only:    copy BNT + bank cluster data only (skip OS cluster).
    """
    try:
        last_pct = [-1]

        def progress(done, total):
            if output_json:
                return
            pct = int(done * 100 / total) if total else 0
            if pct != last_pct[0] and pct % 10 == 0:
                click.echo(f"  {pct}%...", nl=False)
                last_pct[0] = pct

        if not output_json:
            mode_label = "banks-only" if banks_only else "full"
            click.echo(f"🔁 Cloning ({mode_label}): {src_path} → {dst_path}")

        result = clone_disk(
            src_path=src_path,
            dst_path=dst_path,
            banks_only=banks_only,
            progress_cb=progress,
        )

        if not output_json:
            click.echo()  # newline after progress dots
            size_mb = result['size_bytes'] / (1024 * 1024)
            elapsed = result['elapsed_ms']
            click.echo(f"✅ Clone complete — {size_mb:.1f} MB in {elapsed} ms")
            if banks_only:
                click.echo(f"   Banks copied: {result.get('banks_copied', 0)}")
            click.echo(f"   Destination:  {result['dst']}")
        else:
            click.echo(json.dumps(result, indent=2))

    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Clone failed: {e}", err=True)
        sys.exit(1)


@cli.command("move-bank")
@click.option('--src', 'src_path', type=click.Path(exists=True), required=True,
              help='Source disk (.hda)')
@click.option('--dst', 'dst_path', type=click.Path(exists=True), required=True,
              help='Destination disk (.hda)')
@click.option('--bank', 'bank_name', required=True,
              help='Name of bank to move/copy (case-insensitive)')
@click.option('--rename', 'dst_bank_name', default=None,
              help='Rename bank on destination (optional)')
@click.option('--move', 'mode', flag_value='move', default=False,
              help='Move mode: remove bank from source after copy')
@click.option('--copy', 'mode', flag_value='copy', default=True,
              help='Copy mode (default): keep bank on source')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def move_bank_cmd(src_path, dst_path, bank_name, dst_bank_name, mode, output_json):
    """Copy or move a bank directly between two disk images.

    \b
    No intermediate .EB2 file needed — reads cluster data directly.

    Examples:
      # Copy bank from HD10 to HD20
      cli-anything-emaxforge move-bank --src HD10.hda --dst HD20.hda --bank "STEEL DRUMS"

      # Move bank (removes from source)
      cli-anything-emaxforge move-bank --src HD10.hda --dst HD20.hda --bank "STEEL DRUMS" --move

      # Copy and rename on destination
      cli-anything-emaxforge move-bank --src HD10.hda --dst HD20.hda --bank "STEEL DRUMS" --rename "STEEL DRM2"
    """
    try:
        if not output_json:
            action = 'Moving' if mode == 'move' else 'Copying'
            target = f'"{dst_bank_name}"' if dst_bank_name else f'"{bank_name}"'
            click.echo(f"{'🚚' if mode == 'move' else '📋'} {action} bank {target}")
            click.echo(f"   From: {src_path}")
            click.echo(f"   To:   {dst_path}")

        result = move_bank(
            src_path=src_path,
            dst_path=dst_path,
            bank_name=bank_name,
            mode=mode,
            dst_bank_name=dst_bank_name,
        )

        if output_json:
            click.echo(__import__('json').dumps(result, indent=2))
            return

        if result.get('success'):
            elapsed = result['elapsed_ms']
            clusters = result['clusters']
            mb = clusters * 489_472 / (1024 * 1024)
            dst_name = result['dst_bank_name']
            click.echo(f"✅ Done — \"{dst_name}\" → slot {result['dst_slot']} "
                       f"({clusters} clusters / {mb:.1f} MB / {elapsed} ms)")
            if mode == 'move':
                click.echo(f"   Removed from source slot {result['src_slot']}")
        else:
            click.echo(f"❌ {result.get('error')}", err=True)
            sys.exit(1)

    except Exception as e:
        if output_json:
            click.echo(__import__('json').dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("bulk-import")
@click.option('--disk', type=click.Path(exists=True), required=True,
              help='Target disk image (.hda)')
@click.option('--source', required=True,
              help='Directory or glob pattern of .EB2 files to import')
@click.option('--recursive', '-r', is_flag=True, default=False,
              help='Search source directory recursively')
@click.option('--skip-existing', is_flag=True, default=True,
              help='Skip banks already present on disk (default: on)')
@click.option('--no-skip-existing', is_flag=True, default=False,
              help='Re-import banks even if they already exist on disk')
@click.option('--dry-run', is_flag=True, default=False,
              help='Show what would be imported without writing anything')
@click.option('--limit', type=int, default=None,
              help='Max number of banks to import')
@click.option('--sort', type=click.Choice(['name', 'size']), default='name',
              help='Sort order for import (name or size)')
@click.option('--no-progress', is_flag=True, help='Disable progress output')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def bulk_import_cmd(disk, source, recursive, skip_existing, no_skip_existing,
                    dry_run, limit, sort, no_progress, output_json):
    """Bulk import .EB2 banks from a directory or glob pattern.

    \b
    Examples:
      # Import all EB2s from a directory
      cli-anything-emaxforge bulk-import --disk HD20.hda --source /Volumes/EMAX\\ DRIVE/banks/

      # Dry-run: see what would be imported
      cli-anything-emaxforge bulk-import --disk HD20.hda --source ./banks/ --dry-run

      # Import first 50, recursive
      cli-anything-emaxforge bulk-import --disk HD20.hda --source ./banks/ -r --limit 50
    """
    try:
        # --no-skip-existing overrides --skip-existing
        do_skip = skip_existing and not no_skip_existing

        if not output_json and not dry_run:
            click.echo(f"📥 Bulk import → {disk}")
            click.echo(f"   Source:  {source}")
            click.echo(f"   Options: recursive={recursive}, skip_existing={do_skip}, limit={limit}")
            click.echo()

        result = bulk_import(
            disk_path=disk,
            source=source,
            recursive=recursive,
            skip_existing=do_skip,
            dry_run=dry_run,
            progress=not no_progress and not output_json,
            sort_by=sort,
            limit=limit,
        )

        if output_json:
            click.echo(__import__('json').dumps(result, indent=2))
            return

        if dry_run:
            click.echo(f"🔍 Dry run — {result['total_files']} files found")
            click.echo(f"   To import: {result['to_import']}")
            click.echo(f"   To skip:   {result['to_skip']}")
            click.echo(f"   Clusters needed: {result['clusters_needed']} / {result['clusters_free']} free")
            will_fit = result.get('will_fit', False)
            click.echo(f"   Will fit: {'✅ yes' if will_fit else '❌ no — disk will fill up'}")
            return

        if not result.get('success'):
            click.echo(f"❌ {result.get('error')}", err=True)
            sys.exit(1)

        click.echo()
        click.echo(f"✅ Done — {result['imported']} imported, "
                   f"{result['skipped']} skipped, "
                   f"{result['failed']} failed "
                   f"({result['elapsed_ms']} ms)")
        if result.get('disk_full'):
            click.echo("⚠️  Disk full — some banks were not imported")
        if result['failed'] > 0:
            click.echo("\nFailed banks:")
            for r in result['results']:
                if r['status'] == 'error':
                    click.echo(f"  ❌ {r['name']}: {r.get('error', '?')}")

    except Exception as e:
        if output_json:
            click.echo(__import__('json').dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--disk', type=click.Path(exists=True), required=True, help='Disk .hda file')
@click.option('--slot', type=int, required=True, help='Bank slot to export')
@click.option('--output', type=click.Path(), required=True, help='Output .EB2 file')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def export_bank_cmd(disk, slot, output, output_json):
    """Export bank from disk"""
    try:
        result = export_bank(
            disk_path=disk,
            slot=slot,
            output_path=output
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Exported: {result['bank_name']}")
            click.echo(f"   Output: {result['output_path']}")
            click.echo(f"   Size: {result['size_bytes']} bytes")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('input', type=click.Path(exists=True))
@click.argument('output', type=click.Path())
@click.option('--rate', type=int, default=42000, help='Target sample rate (default: 42000 Hz)')
@click.option('--mono', is_flag=True, help='Convert to mono')
@click.option('--normalize', is_flag=True, help='Normalize volume')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def convert_audio(input, output, rate, mono, normalize, output_json):
    """Convert audio file (WAV/AIFF) for EMAX II"""
    try:
        converter = AudioConverter()
        result = converter.convert_advanced(
            input,
            output,
            target_rate=rate,
            mono=mono,
            normalize=normalize
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Converted: {result['input']} → {result['output']}")
            if result['input_rate'] != result['output_rate']:
                click.echo(f"   Rate: {result['input_rate']} → {result['output_rate']} Hz")
            click.echo(f"   Channels: {result['channels']}")
            click.echo(f"   Frames: {result['frames']}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('pattern')
@click.option('--output-dir', required=True, help='Output directory')
@click.option('--rate', type=int, default=42000, help='Target sample rate')
@click.option('--mono', is_flag=True, help='Convert to mono')
@click.option('--normalize', is_flag=True, help='Normalize volume')
@click.option('--no-progress', is_flag=True, help='Disable progress bar')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def batch_convert(pattern, output_dir, rate, mono, normalize, no_progress, output_json):
    """Batch convert audio files"""
    try:
        batch = BatchOperations()
        result = batch.batch_convert_audio(
            pattern,
            output_dir,
            target_rate=rate,
            mono=mono,
            normalize=normalize,
            progress=not no_progress
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            if result.get("success"):
                click.echo(f"\n✅ Converted: {result['converted']}/{result['total']}")
                if result.get("errors", 0) > 0:
                    click.echo(f"   Errors: {result['errors']}")
            else:
                click.echo(f"❌ Error: {result.get('error')}", err=True)
                sys.exit(1)
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('disk', type=click.Path(exists=True))
@click.argument('pattern')
@click.option('--no-progress', is_flag=True, help='Disable progress bar')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def batch_import_banks(disk, pattern, no_progress, output_json):
    """Batch import .EB2 banks to disk"""
    try:
        batch = BatchOperations()
        result = batch.batch_import_banks(
            disk,
            pattern,
            progress=not no_progress
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            if result.get("success"):
                click.echo(f"\n✅ Imported: {result['imported']}/{result['total']}")
                if result.get("errors", 0) > 0:
                    click.echo(f"   Errors: {result['errors']}")
            else:
                click.echo(f"❌ Error: {result.get('error')}", err=True)
                sys.exit(1)
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('disk', type=click.Path(exists=True))
@click.option('--output-dir', required=True, help='Output directory')
@click.option('--filter', default='*', help='Bank name filter pattern')
@click.option('--no-progress', is_flag=True, help='Disable progress bar')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def batch_export_banks(disk, output_dir, filter, no_progress, output_json):
    """Batch export all banks from disk"""
    try:
        batch = BatchOperations()
        result = batch.batch_export_banks(
            disk,
            output_dir,
            filter_pattern=filter,
            progress=not no_progress
        )
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            if result.get("success"):
                click.echo(f"\n✅ Exported: {result['exported']}/{result['total']}")
                if result.get("errors", 0) > 0:
                    click.echo(f"   Errors: {result['errors']}")
            else:
                click.echo(f"❌ Error: {result.get('error')}", err=True)
                sys.exit(1)
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('output', type=click.Path())
@click.option('--device', default='EMAX II', help='Device type')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def generate_zulu_config(output, device, output_json):
    """Generate zuluscsi.ini configuration file"""
    try:
        result = ZuluSCSIConfig.write(output, device_type=device)
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Created: {result['file']}")
            click.echo(f"   Size: {result['size']} bytes")
            click.echo(f"\n{result['content']}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('config', type=click.Path(exists=True))
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def validate_zulu_config(config, output_json):
    """Validate zuluscsi.ini configuration"""
    try:
        result = ZuluSCSIConfig.validate(config)
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            if result.get("valid"):
                click.echo("✅ Config is valid")
                for check, passed in result["checks"].items():
                    status = "✓" if passed else "✗"
                    click.echo(f"  {status} {check}")
                
                if result.get("warnings"):
                    click.echo("\nWarnings:")
                    for warning in result["warnings"]:
                        click.echo(f"  ⚠️  {warning}")
            else:
                click.echo("❌ Config validation failed")
                if result.get("error"):
                    click.echo(f"   {result['error']}")
                elif result.get("checks"):
                    for check, passed in result["checks"].items():
                        status = "✓" if passed else "✗"
                        click.echo(f"  {status} {check}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('directory', type=click.Path(exists=True))
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def scan_zulu_images(directory, output_json):
    """Scan directory for .hda disk images"""
    try:
        images = ZuluSCSIConfig.find_images(directory)
        
        if output_json:
            click.echo(json.dumps({"images": images, "count": len(images)}, indent=2))
        else:
            if images:
                click.echo(f"Found {len(images)} disk image(s):\n")
                for img in images:
                    click.echo(f"  SCSI ID {img['scsi_id']}: {img['filename']} ({img['size_mb']} MB)")
            else:
                click.echo("No .hda images found")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('disk', type=click.Path(exists=True))
@click.option('--include-os', is_flag=True, help='Include OS entry')
@click.option('--include-empty', is_flag=True, help='Include empty entries')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def list_catalog(disk, include_os, include_empty, output_json):
    """List disk catalog entries (banks)"""
    try:
        entries = CatalogParser.list_banks(disk, include_os=include_os, include_empty=include_empty)
        cluster_size = CatalogParser.get_cluster_size(disk)
        
        if output_json:
            result = {
                "count": len(entries),
                "cluster_size": cluster_size,
                "entries": [e.to_dict(cluster_size) for e in entries]
            }
            click.echo(json.dumps(result, indent=2))
        else:
            if entries:
                click.echo(f"Found {len(entries)} catalog entries:\n")
                for entry in entries:
                    icon = "💿" if entry.is_os else "🎹"
                    size_mb = entry.size_mb(cluster_size)
                    click.echo(f"{icon} {entry.name}")
                    click.echo(f"   Cluster: {entry.cluster}, Size: {size_mb:.2f} MB")
                    if entry.preset_count > 0:
                        click.echo(f"   Presets: {entry.preset_count}")
            else:
                click.echo("No active entries found")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('disk', type=click.Path(exists=True))
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def catalog_summary(disk, output_json):
    """Show catalog summary with statistics"""
    try:
        summary = CatalogParser.summary(disk)
        
        if output_json:
            click.echo(json.dumps(summary, indent=2))
        else:
            click.echo(f"📊 Catalog Summary\n")
            click.echo(f"Total entries: {summary['total_entries']}")
            click.echo(f"Active entries: {summary['active_entries']}")
            click.echo(f"Banks: {summary['bank_count']}")
            click.echo(f"Cluster size: {summary['cluster_size']} bytes")
            
            if summary['os_entry']:
                os = summary['os_entry']
                click.echo(f"\n💿 OS: {os['name']}")
                click.echo(f"   Cluster: {os['cluster']}, Size: {os['size_mb']:.2f} MB")
            
            if summary['entries']:
                click.echo(f"\n🎹 Banks ({len(summary['entries'])}):")
                for entry in summary['entries']:
                    if not entry['is_os']:
                        click.echo(f"   • {entry['name']} ({entry['size_mb']:.2f} MB)")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def list_templates(output_json):
    """List available bank templates"""
    try:
        templates = BankTemplates.list_templates()
        
        if output_json:
            click.echo(json.dumps({"templates": templates, "count": len(templates)}, indent=2))
        else:
            click.echo(f"📦 Available Bank Templates ({len(templates)}):\n")
            for tmpl in templates:
                click.echo(f"  • {tmpl['name']:<15} - {tmpl['description']}")
                click.echo(f"    Presets: {tmpl['presets']}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('template')
@click.argument('output', type=click.Path())
@click.option('--name', help='Custom bank name')
@click.option('--preset-count', type=int, help='Preset count (for EMPTY template)')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def create_template(template, output, name, preset_count, output_json):
    """Create bank from template
    
    TEMPLATE: Template name (INIT, PERCUSSION, BASS, PADS, LEADS, FX, EMPTY)
    OUTPUT: Output .EB2 file path
    """
    try:
        kwargs = {}
        if name:
            kwargs['name'] = name
        if preset_count:
            kwargs['preset_count'] = preset_count
        
        result = BankTemplates.create(template, output, **kwargs)
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Created: {result['file']}")
            click.echo(f"   Size: {result['size']} bytes")
            click.echo(f"   Presets: {result['presets']}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('disk', type=click.Path(exists=True))
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def analyze_fat(disk, output_json):
    """Analyze FAT structure and detect errors"""
    try:
        analyzer = FATAnalyzer(disk)
        result = analyzer.analyze()
        
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"📊 FAT Analysis\n")
            click.echo(f"Cluster size: {result['cluster_size']} bytes")
            click.echo(f"Total clusters: {result['total_clusters']}")
            click.echo(f"FAT entries: {result['fat_entries']}")
            click.echo(f"\nChains: {result['chain_count']}")
            click.echo(f"Allocated: {result['allocated_clusters']} clusters")
            click.echo(f"Free: {result['free_clusters']} clusters")
            click.echo(f"Usage: {result['usage_percent']}%")
            
            if result['circular_chains'] > 0:
                click.echo(f"\n🔁 Circular chains: {result['circular_chains']}")
            
            if result['broken_chains'] > 0:
                click.echo(f"\n💔 Broken chains: {result['broken_chains']}")
            
            if result['orphaned_count'] > 0:
                click.echo(f"\n👻 Orphaned clusters: {result['orphaned_count']}")
                click.echo(f"   {result['orphaned_clusters'][:10]}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.argument('disk', type=click.Path(exists=True))
@click.argument('cluster', type=int)
@click.option('--json', 'output_json', is_flag=True, help='Output JSON')
def visualize_chain(disk, cluster, output_json):
    """Visualize FAT chain starting from cluster"""
    try:
        analyzer = FATAnalyzer(disk)
        chain = analyzer.follow_chain(cluster)
        
        if output_json:
            click.echo(json.dumps(chain.to_dict(), indent=2))
        else:
            viz = analyzer.visualize_chain(cluster)
            click.echo(f"\n🔗 FAT Chain (start={cluster}):\n")
            click.echo(viz)
            click.echo(f"\nLength: {chain.length} clusters")
            
            if chain.is_circular:
                click.echo("⚠️  CIRCULAR REFERENCE DETECTED")
            if chain.is_broken:
                click.echo("⚠️  BROKEN CHAIN DETECTED")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("create-boot-disk")
@click.option("--size", type=click.Choice(["96", "239", "481", "633", "962"]),
              default="239", help="Disk size in MB")
@click.option("--os-version", default="2.14", help="EMAX II OS version label")
@click.option("--scsi-id", type=int, default=1, help="ZuluSCSI SCSI ID")
@click.option("--output", type=click.Path(), required=True, help="Output .hda path")
@click.option("--json", "output_json", is_flag=True, help="Output JSON")
def create_boot_disk_cmd(size, os_version, scsi_id, output, output_json):
    """Create a bootable EMAX II HD disk image from template"""
    try:
        result = create_boot_disk(
            size_mb=int(size),
            output_path=output,
            os_version=os_version,
            scsi_id=scsi_id,
        )
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            sig = "✅" if result["boot_signature_valid"] else "❌"
            click.echo(f"✅ Created boot disk: {result['path']}")
            click.echo(f"   Size:      {result['size_mb']} MB")
            click.echo(f"   SCSI ID:   {result['scsi_id']}")
            click.echo(f"   OS:        {result['os_version']}")
            click.echo(f"   Boot sig:  {sig}")
            click.echo(f"   ZuluSCSI:  {result['zuluscsi_name']}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("create-floppy")
@click.option("--size", type=click.Choice(["180K", "800K", "1440K"]),
              default="800K", help="Floppy capacity")
@click.option("--format", "fmt", type=click.Choice(["raw", "hfe"]),
              default="hfe", help="Image format (raw IMG or HFE for Gotek)")
@click.option("--output", type=click.Path(), required=True, help="Output .img/.hfe path")
@click.option("--json", "output_json", is_flag=True, help="Output JSON")
def create_floppy_cmd(size, fmt, output, output_json):
    """Create a blank EMAX II floppy image for Gotek/HxC emulator"""
    try:
        result = create_floppy(size=size, output_path=output, format_type=fmt)
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Created floppy: {result['path']}")
            click.echo(f"   Format:  {result['format'].upper()}")
            click.echo(f"   Size:    {result['size_label']}")
            click.echo(f"   Tracks:  {result['tracks']} × {result['sides']} sides")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("list-images")
@click.argument("directory", type=click.Path(exists=True), default=".")
@click.option("--json", "output_json", is_flag=True, help="Output JSON")
def list_images_cmd(directory, output_json):
    """List all EMAX II disk images in a directory"""
    try:
        result = _list_images(directory)
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"📂 {result['directory']}  ({result['count']} images)\n")
            for img in result["images"]:
                kind = "FD" if img["type"] == "floppy" else "HD"
                boot = " [BOOT]" if img.get("is_boot") else ""
                click.echo(f"  [{kind}] {img['filename']:30s}  {img['size_mb']:4d} MB{boot}")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("verify-boot")
@click.argument("image", type=click.Path(exists=True))
@click.option("--json", "output_json", is_flag=True, help="Output JSON")
def verify_boot_cmd(image, output_json):
    """Verify a boot disk image structure (boot sig, FAT, catalog)"""
    try:
        result = verify_boot_disk(image)
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            status = "✅ VALID" if result["valid"] else "❌ INVALID"
            click.echo(f"{status}: {result['disk_path']}  ({result['size_mb']} MB)\n")
            for check in result["checks"]:
                icon = "  ✓" if check["passed"] else "  ✗"
                click.echo(f"{icon} {check['name']}: {check['message']}")
        if not result["valid"]:
            sys.exit(1)
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("convert-hfe")
@click.argument("hfe_file", type=click.Path(exists=True))
@click.argument("output", type=click.Path())
@click.option("--json", "output_json", is_flag=True, help="Output JSON")
def convert_hfe_cmd(hfe_file, output, output_json):
    """Convert HFE floppy image to raw IMG format"""
    try:
        result = convert_hfe_to_img(hfe_file, output)
        if output_json:
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"✅ Converted: {result['source']} → {result['output']}")
            click.echo(f"   Tracks: {result['tracks']} × {result['sides']} sides")
            click.echo(f"   Size:   {result['size_bytes']:,} bytes")
    except Exception as e:
        if output_json:
            click.echo(json.dumps({"error": str(e)}))
        else:
            click.echo(f"❌ Error: {e}", err=True)
        sys.exit(1)


@cli.command("repl")
def repl_cmd():
    """Interactive REPL mode — enter commands one per line (Ctrl-D to quit)"""
    import shlex
    click.echo("EmaxForge REPL  (type 'help' for commands, Ctrl-D to quit)\n")
    while True:
        try:
            line = click.prompt("emaxforge", prompt_suffix="> ", default="", show_default=False)
        except (click.Abort, EOFError):
            click.echo("\nBye!")
            break
        line = line.strip()
        if not line or line in ("quit", "exit"):
            click.echo("Bye!")
            break
        try:
            args = shlex.split(line)
            cli.main(args, standalone_mode=False)
        except SystemExit:
            pass
        except Exception as exc:
            click.echo(f"Error: {exc}")


if __name__ == "__main__":
    cli()
