#!/usr/bin/env python3
"""
Swift Backend - Wrapper for EmaxForge's native Swift CLIs

Wraps existing scripts:
- cli-create-test-disks.swift
- cli-import-eb2-banks.swift
- cli-import-samples.swift
"""

import subprocess
import json
from pathlib import Path
from typing import Optional, Dict, Any


class SwiftBackend:
    """Execute Swift CLI scripts and parse output"""
    
    def __init__(self, repo_root: Optional[Path] = None):
        if repo_root is None:
            # Auto-detect EmaxForge repo
            repo_root = Path.home() / "clawd" / "EmaxForge"
        
        self.repo_root = Path(repo_root)
    
    def _run_swift(self, script_name: str, args: list[str]) -> Dict[str, Any]:
        """Run a Swift CLI script and return result"""
        script_path = self.repo_root / script_name
        
        if not script_path.exists():
            return {
                "success": False,
                "error": f"Script not found: {script_path}",
            }
        
        cmd = ["swift", str(script_path)] + args
        
        try:
            result = subprocess.run(
                cmd,
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=60,
            )
            
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode,
            }
        
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Command timed out after 60s",
            }
        
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
            }
    
    def create_disk(
        self,
        output: Path,
        size_mb: int = 239,
        boot: bool = False,
        scsi_id: int = 1,
    ) -> Dict[str, Any]:
        """Create disk image via cli-create-disk.swift"""
        
        args = [
            "--size", str(size_mb),
            "--output", str(output),
            "--scsi-id", str(scsi_id),
        ]
        
        if boot:
            args.append("--boot")
        
        result = self._run_swift("cli-create-disk.swift", args)
        
        # Parse JSON output if present
        if result["success"] and "JSON_OUTPUT_START" in result["stdout"]:
            try:
                json_start = result["stdout"].index("JSON_OUTPUT_START") + len("JSON_OUTPUT_START\n")
                json_end = result["stdout"].index("JSON_OUTPUT_END")
                json_str = result["stdout"][json_start:json_end].strip()
                
                import json
                parsed = json.loads(json_str)
                result.update(parsed)
            except (ValueError, json.JSONDecodeError):
                pass
        
        return result
    
    def export_bank(
        self,
        disk: Path,
        index: Optional[int] = None,
        name: Optional[str] = None,
        output: Path = None,
    ) -> Dict[str, Any]:
        """Export bank from disk via cli-export-bank.swift"""
        
        args = ["--disk", str(disk), "--output", str(output)]
        
        if index is not None:
            args.extend(["--index", str(index)])
        elif name is not None:
            args.extend(["--name", name])
        else:
            return {
                "success": False,
                "error": "Either index or name required",
            }
        
        result = self._run_swift("cli-export-bank.swift", args)
        
        # Parse JSON
        if result["success"] and "JSON_OUTPUT_START" in result["stdout"]:
            try:
                json_start = result["stdout"].index("JSON_OUTPUT_START") + len("JSON_OUTPUT_START\n")
                json_end = result["stdout"].index("JSON_OUTPUT_END")
                json_str = result["stdout"][json_start:json_end].strip()
                
                import json
                parsed = json.loads(json_str)
                result.update(parsed)
            except (ValueError, json.JSONDecodeError):
                pass
        
        return result
    
    def import_bank(
        self,
        disk: Path,
        bank_file: Path,
        slot: Optional[int] = None,
    ) -> Dict[str, Any]:
        """Import .EB2 bank via cli-import-eb2-banks.swift"""
        
        args = [str(disk), str(bank_file)]
        if slot is not None:
            args.append(str(slot))
        
        return self._run_swift("cli-import-eb2-banks.swift", args)
    
    def list_banks(
        self,
        disk: Path,
    ) -> Dict[str, Any]:
        """List banks via cli-list-banks.swift"""
        
        args = ["--disk", str(disk)]
        
        result = self._run_swift("cli-list-banks.swift", args)
        
        # Parse JSON
        if result["success"] and "JSON_OUTPUT_START" in result["stdout"]:
            try:
                json_start = result["stdout"].index("JSON_OUTPUT_START") + len("JSON_OUTPUT_START\n")
                json_end = result["stdout"].index("JSON_OUTPUT_END")
                json_str = result["stdout"][json_start:json_end].strip()
                
                import json
                parsed = json.loads(json_str)
                result["banks"] = parsed
            except (ValueError, json.JSONDecodeError):
                result["banks"] = []
        
        return result
    
    def clone_disk(
        self,
        source: Path,
        output: Path,
        verify: bool = False,
    ) -> Dict[str, Any]:
        """Clone disk (bit-for-bit copy) via cli-clone-disk.swift"""
        
        args = ["--source", str(source), "--output", str(output)]
        if verify:
            args.append("--verify")
        
        result = self._run_swift("cli-clone-disk.swift", args)
        
        # Parse JSON
        if result["success"] and "JSON_OUTPUT_START" in result["stdout"]:
            try:
                json_start = result["stdout"].index("JSON_OUTPUT_START") + len("JSON_OUTPUT_START\n")
                json_end = result["stdout"].index("JSON_OUTPUT_END")
                json_str = result["stdout"][json_start:json_end].strip()
                
                import json
                parsed = json.loads(json_str)
                result.update(parsed)
            except (ValueError, json.JSONDecodeError):
                pass
        
        return result
    
    def update_os(
        self,
        disks: list[Path],
        os_file: Path,
        verify: bool = False,
    ) -> Dict[str, Any]:
        """Mass OS update via cli-update-os.swift"""
        
        disk_paths = ",".join(str(d) for d in disks)
        args = ["--disks", disk_paths, "--os", str(os_file)]
        if verify:
            args.append("--verify")
        
        result = self._run_swift("cli-update-os.swift", args)
        
        # Parse JSON
        if result["success"] and "JSON_OUTPUT_START" in result["stdout"]:
            try:
                json_start = result["stdout"].index("JSON_OUTPUT_START") + len("JSON_OUTPUT_START\n")
                json_end = result["stdout"].index("JSON_OUTPUT_END")
                json_str = result["stdout"][json_start:json_end].strip()
                
                import json
                parsed = json.loads(json_str)
                result.update(parsed)
            except (ValueError, json.JSONDecodeError):
                pass
        
        return result
    
    def validate_disk(
        self,
        disk: Path,
        fix: bool = False,
    ) -> Dict[str, Any]:
        """Validate disk image via cli-validate-disk.swift"""
        
        args = ["--disk", str(disk)]
        if fix:
            args.append("--fix")
        
        result = self._run_swift("cli-validate-disk.swift", args)
        
        # Parse JSON
        if "JSON_OUTPUT_START" in result["stdout"]:
            try:
                json_start = result["stdout"].index("JSON_OUTPUT_START") + len("JSON_OUTPUT_START\n")
                json_end = result["stdout"].index("JSON_OUTPUT_END")
                json_str = result["stdout"][json_start:json_end].strip()
                
                import json
                parsed = json.loads(json_str)
                result.update(parsed)
            except (ValueError, json.JSONDecodeError):
                pass
        
        return result
    
    def import_samples(
        self,
        disk: Path,
        wav_files: list[Path],
        bank_name: str = "CONVERTED",
    ) -> Dict[str, Any]:
        """Convert WAV → EMAX II via cli-import-samples.swift"""
        
        args = [str(disk), bank_name] + [str(f) for f in wav_files]
        
        return self._run_swift("cli-import-samples.swift", args)
    
    def build_app(self) -> Dict[str, Any]:
        """Build EmaxForge.app via build.sh"""
        
        build_script = self.repo_root / "build.sh"
        if not build_script.exists():
            return {
                "success": False,
                "error": "build.sh not found",
            }
        
        try:
            result = subprocess.run(
                ["./build.sh"],
                cwd=self.repo_root,
                capture_output=True,
                text=True,
                timeout=120,  # 2 min timeout
            )
            
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "app_path": str(self.app_path) if self.app_path.exists() else None,
            }
        
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Build timed out after 2 minutes",
            }
        
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
            }


# ============================================================
# Standalone test
# ============================================================

if __name__ == "__main__":
    backend = SwiftBackend()
    
    print(f"EmaxForge repo: {backend.repo_root}")
    print(f"App exists: {backend.app_path.exists()}")
    
    # Test build
    print("\nTesting build...")
    result = backend.build_app()
    print(f"Build success: {result['success']}")
    
    if result['success']:
        print(f"App path: {result['app_path']}")
