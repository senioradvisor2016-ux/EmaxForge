#!/usr/bin/env python3
"""
Batch operations for format compatibility
Features: batch convert WAV, batch import/export banks, progress reporting
"""

import sys
import json
import glob
from pathlib import Path
from typing import List, Dict, Any
import time

# Import other handlers
from .audio_converter import AudioConverter


class ProgressReporter:
    """Real-time progress reporting for batch operations"""
    
    def __init__(self, total: int, show_bar: bool = True):
        self.total = total
        self.current = 0
        self.start_time = time.time()
        self.show_bar = show_bar
    
    def update(self, increment: int = 1, item_name: str = ""):
        """Update progress"""
        self.current += increment
        percent = (self.current / self.total) * 100 if self.total > 0 else 0
        elapsed = time.time() - self.start_time
        rate = self.current / elapsed if elapsed > 0 else 0
        eta = (self.total - self.current) / rate if rate > 0 else 0
        
        if self.show_bar:
            # Progress bar
            bar_width = 40
            filled = int(bar_width * self.current / self.total) if self.total > 0 else 0
            bar = "█" * filled + "░" * (bar_width - filled)
            
            # Print with item name
            item_text = f" {item_name}" if item_name else ""
            print(f"\r[{bar}] {percent:.1f}% ({self.current}/{self.total}) ETA: {eta:.0f}s{item_text}", 
                  end="", flush=True, file=sys.stderr)
        else:
            # Simple JSON progress
            print(json.dumps({
                "type": "progress",
                "current": self.current,
                "total": self.total,
                "percent": percent,
                "eta_seconds": eta,
                "item": item_name
            }), flush=True)
    
    def finish(self):
        """Mark complete"""
        if self.show_bar:
            print("\n✅ Complete!", file=sys.stderr)
        else:
            print(json.dumps({"type": "complete"}), flush=True)


class BatchOperations:
    """Batch operations handler"""
    
    def __init__(self):
        self.converter = AudioConverter()
    
    def batch_convert_audio(
        self,
        pattern: str,
        output_dir: str,
        target_rate: int = 42000,
        mono: bool = True,
        normalize: bool = True,
        progress: bool = True
    ) -> Dict[str, Any]:
        """Batch convert audio files"""
        
        # Expand pattern
        files = glob.glob(pattern, recursive=True)
        
        if not files:
            return {
                "success": False,
                "error": f"No files found matching pattern: {pattern}"
            }
        
        # Create output directory
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Progress reporter
        reporter = ProgressReporter(len(files), show_bar=progress) if progress else None
        
        results = []
        success_count = 0
        error_count = 0
        
        for file_path in files:
            file_name = Path(file_path).stem
            output_file = output_path / f"{file_name}.wav"
            
            try:
                result = self.converter.convert_advanced(
                    file_path,
                    str(output_file),
                    target_rate=target_rate,
                    mono=mono,
                    normalize=normalize
                )
                
                results.append({
                    "input": file_path,
                    "output": str(output_file),
                    "status": "success"
                })
                success_count += 1
                
            except Exception as e:
                results.append({
                    "input": file_path,
                    "status": "error",
                    "error": str(e)
                })
                error_count += 1
            
            if reporter:
                reporter.update(item_name=Path(file_path).name)
        
        if reporter:
            reporter.finish()
        
        return {
            "success": True,
            "total": len(files),
            "converted": success_count,
            "errors": error_count,
            "results": results
        }
    
    def batch_import_banks(
        self,
        disk_path: str,
        pattern: str,
        progress: bool = True
    ) -> Dict[str, Any]:
        """Batch import .EB2 banks to disk"""
        
        # Import disk module dynamically
        try:
            from cli_anything.emaxforge.core.bank import import_bank as import_bank_fn
        except ImportError:
            return {"success": False, "error": "Bank import module not available"}
        
        # Expand pattern
        banks = glob.glob(pattern, recursive=True)
        
        if not banks:
            return {
                "success": False,
                "error": f"No .EB2 files found matching pattern: {pattern}"
            }
        
        # Progress reporter
        reporter = ProgressReporter(len(banks), show_bar=progress) if progress else None
        
        results = []
        imported_count = 0
        error_count = 0
        
        for bank_path in banks:
            try:
                # Call existing import_bank function
                result = import_bank_fn(disk_path, bank_path)
                
                if result.get("success"):
                    results.append({
                        "bank": bank_path,
                        "status": "imported"
                    })
                    imported_count += 1
                else:
                    results.append({
                        "bank": bank_path,
                        "status": "error",
                        "error": result.get("error", "Unknown error")
                    })
                    error_count += 1
                    
            except Exception as e:
                results.append({
                    "bank": bank_path,
                    "status": "error",
                    "error": str(e)
                })
                error_count += 1
            
            if reporter:
                reporter.update(item_name=Path(bank_path).name)
        
        if reporter:
            reporter.finish()
        
        return {
            "success": True,
            "total": len(banks),
            "imported": imported_count,
            "errors": error_count,
            "results": results
        }
    
    def batch_export_banks(
        self,
        disk_path: str,
        output_dir: str,
        filter_pattern: str = "*",
        progress: bool = True
    ) -> Dict[str, Any]:
        """Batch export all banks from disk"""
        
        # Import disk module dynamically
        try:
            from cli_anything.emaxforge.core.bank import list_banks as list_banks_fn
            from cli_anything.emaxforge.core.bank import export_bank as export_bank_fn
        except ImportError:
            return {"success": False, "error": "Bank export module not available"}
        
        # List banks
        try:
            banks_result = list_banks_fn(disk_path)
            if not banks_result.get("success"):
                return {"success": False, "error": "Failed to list banks"}
            
            banks = banks_result.get("banks", [])
            
            # Apply filter
            import fnmatch
            if filter_pattern != "*":
                banks = [b for b in banks if fnmatch.fnmatch(b["name"], filter_pattern)]
            
            if not banks:
                return {"success": False, "error": "No banks found on disk"}
            
        except Exception as e:
            return {"success": False, "error": f"Failed to list banks: {str(e)}"}
        
        # Create output directory
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Progress reporter
        reporter = ProgressReporter(len(banks), show_bar=progress) if progress else None
        
        results = []
        exported_count = 0
        error_count = 0
        
        for bank in banks:
            bank_name = bank["name"]
            output_file = output_path / f"{bank_name}.EB2"
            
            try:
                result = export_bank_fn(disk_path, bank_name, str(output_file))
                
                if result.get("success"):
                    results.append({
                        "bank": bank_name,
                        "output": str(output_file),
                        "status": "exported"
                    })
                    exported_count += 1
                else:
                    results.append({
                        "bank": bank_name,
                        "status": "error",
                        "error": result.get("error", "Unknown error")
                    })
                    error_count += 1
                    
            except Exception as e:
                results.append({
                    "bank": bank_name,
                    "status": "error",
                    "error": str(e)
                })
                error_count += 1
            
            if reporter:
                reporter.update(item_name=bank_name)
        
        if reporter:
            reporter.finish()
        
        return {
            "success": True,
            "total": len(banks),
            "exported": exported_count,
            "errors": error_count,
            "results": results
        }


def main():
    """CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Batch operations for standard tools')
    subparsers = parser.add_subparsers(dest='command')
    
    # batch-convert
    convert_parser = subparsers.add_parser('batch-convert', help='Batch convert audio files')
    convert_parser.add_argument('pattern', help='File pattern (e.g., "*.wav")')
    convert_parser.add_argument('--output-dir', required=True, help='Output directory')
    convert_parser.add_argument('--rate', type=int, default=42000, help='Target sample rate')
    convert_parser.add_argument('--mono', action='store_true', help='Convert to mono')
    convert_parser.add_argument('--normalize', action='store_true', help='Normalize volume')
    convert_parser.add_argument('--no-progress', action='store_true', help='Disable progress bar')
    convert_parser.add_argument('--json', action='store_true', help='JSON output')
    
    # batch-import-banks
    import_parser = subparsers.add_parser('batch-import-banks', help='Batch import banks')
    import_parser.add_argument('disk', help='Disk image path')
    import_parser.add_argument('pattern', help='Bank file pattern (e.g., "*.EB2")')
    import_parser.add_argument('--no-progress', action='store_true', help='Disable progress bar')
    import_parser.add_argument('--json', action='store_true', help='JSON output')
    
    # batch-export-banks
    export_parser = subparsers.add_parser('batch-export-banks', help='Batch export banks')
    export_parser.add_argument('disk', help='Disk image path')
    export_parser.add_argument('--output-dir', required=True, help='Output directory')
    export_parser.add_argument('--filter', default='*', help='Bank name filter')
    export_parser.add_argument('--no-progress', action='store_true', help='Disable progress bar')
    export_parser.add_argument('--json', action='store_true', help='JSON output')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    batch = BatchOperations()
    
    try:
        if args.command == 'batch-convert':
            result = batch.batch_convert_audio(
                args.pattern,
                args.output_dir,
                target_rate=args.rate,
                mono=args.mono,
                normalize=args.normalize,
                progress=not args.no_progress
            )
        elif args.command == 'batch-import-banks':
            result = batch.batch_import_banks(
                args.disk,
                args.pattern,
                progress=not args.no_progress
            )
        elif args.command == 'batch-export-banks':
            result = batch.batch_export_banks(
                args.disk,
                args.output_dir,
                filter_pattern=args.filter,
                progress=not args.no_progress
            )
        else:
            print(f"Unknown command: {args.command}", file=sys.stderr)
            return 1
        
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            if result.get("success"):
                print(f"\n✅ Success!")
                if "converted" in result:
                    print(f"   Converted: {result['converted']}/{result['total']}")
                if "imported" in result:
                    print(f"   Imported: {result['imported']}/{result['total']}")
                if "exported" in result:
                    print(f"   Exported: {result['exported']}/{result['total']}")
                if result.get("errors", 0) > 0:
                    print(f"   Errors: {result['errors']}")
            else:
                print(f"❌ Error: {result.get('error', 'Unknown error')}", file=sys.stderr)
                return 1
        
        return 0
    
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
