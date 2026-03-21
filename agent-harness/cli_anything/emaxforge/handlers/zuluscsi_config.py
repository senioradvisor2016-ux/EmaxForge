"""
ZuluSCSI configuration file generation
Based on working Funkar config (minimal compatible setup)
"""

import os
from pathlib import Path
from typing import List, Optional


class ZuluSCSIConfig:
    """Generate zuluscsi.ini for EMAX II"""
    
    MINIMAL_CONFIG = """; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
"""
    
    @staticmethod
    def generate(device_type: str = "EMAX II") -> str:
        """Generate minimal working config"""
        return ZuluSCSIConfig.MINIMAL_CONFIG
    
    @staticmethod
    def write(output_path: str, device_type: str = "EMAX II") -> dict:
        """Write config to file
        
        Args:
            output_path: Output file path (zuluscsi.ini)
            device_type: Device type (default: EMAX II)
        
        Returns:
            {
                "file": str,
                "size": int,
                "content": str
            }
        """
        config = ZuluSCSIConfig.generate(device_type)
        
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w') as f:
            f.write(config)
        
        size = os.path.getsize(output_path)
        
        return {
            "file": str(output_path),
            "size": size,
            "content": config
        }
    
    @staticmethod
    def validate(config_path: str) -> dict:
        """Validate existing config
        
        Args:
            config_path: Path to zuluscsi.ini
        
        Returns:
            {
                "valid": bool,
                "checks": {check_name: bool},
                "warnings": [str]
            }
        """
        if not os.path.exists(config_path):
            return {
                "valid": False,
                "error": "File not found"
            }
        
        with open(config_path, 'r') as f:
            content = f.read()
        
        checks = {
            "has_scsi_section": "[SCSI]" in content,
            "has_enable_parity": "EnableParity" in content,
            "has_scsi1_section": "[SCSI1]" in content
        }
        
        warnings = []
        
        if "EnableMAC" in content:
            warnings.append("EnableMAC is not needed for EMAX II (auto-detected)")
        
        if "SelectionDelay" not in content:
            warnings.append("Consider adding SelectionDelay = 255 for reliability")
        
        return {
            "valid": all(checks.values()),
            "checks": checks,
            "warnings": warnings,
            "content": content
        }
    
    @staticmethod
    def find_images(directory: str) -> List[dict]:
        """Find .hda images in directory
        
        Args:
            directory: Path to search
        
        Returns:
            [{"filename": str, "scsi_id": int, "size_mb": int}]
        """
        path = Path(directory)
        images = []
        
        for file in path.glob("*.hda"):
            # Parse SCSI ID from filename (HD00.hda -> 0, HD10.hda -> 1)
            try:
                name = file.stem.upper()
                if name.startswith("HD"):
                    scsi_id = int(name[2:3])  # First digit after HD
                    size_mb = file.stat().st_size // (1024 * 1024)
                    
                    images.append({
                        "filename": file.name,
                        "scsi_id": scsi_id,
                        "size_mb": size_mb
                    })
            except (ValueError, IndexError):
                continue
        
        return sorted(images, key=lambda x: x["scsi_id"])
