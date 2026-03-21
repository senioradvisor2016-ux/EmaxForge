"""
EMAX II Bank Templates
Pre-fabricated banks for common use cases
"""

import struct
from pathlib import Path
from typing import Dict, Any, Optional, List


class BankTemplate:
    """Pre-fabricated EMAX II bank structure"""
    
    # Bank header format (simplified)
    BANK_HEADER_SIZE = 512
    PRESET_SIZE = 512
    SAMPLE_HEADER_SIZE = 256
    
    def __init__(self, name: str, preset_count: int = 100):
        self.name = name[:16].ljust(16, '\x00')  # Max 16 chars
        self.preset_count = min(preset_count, 100)  # Max 100 presets
        self.presets: List[Dict[str, Any]] = []
        self.samples: List[Dict[str, Any]] = []
    
    def add_preset(self, preset_name: str, **kwargs):
        """Add preset to bank"""
        preset = {
            "name": preset_name[:16].ljust(16, '\x00'),
            "volume": kwargs.get("volume", 127),
            "pan": kwargs.get("pan", 0),
            "transpose": kwargs.get("transpose", 0),
            **kwargs
        }
        self.presets.append(preset)
    
    def add_sample(self, sample_name: str, rate: int = 42000, **kwargs):
        """Add sample to bank"""
        sample = {
            "name": sample_name[:16].ljust(16, '\x00'),
            "rate": rate,
            "length": kwargs.get("length", 0),
            **kwargs
        }
        self.samples.append(sample)
    
    def to_bytes(self) -> bytes:
        """Serialize bank to .EB2 format"""
        # Simplified bank structure
        data = bytearray(self.BANK_HEADER_SIZE)
        
        # Bank name
        data[0:16] = self.name.encode('ascii')[:16]
        
        # Preset count
        struct.pack_into('<H', data, 16, self.preset_count)
        
        # Sample count
        struct.pack_into('<H', data, 18, len(self.samples))
        
        # Add presets (simplified - just names for now)
        for i, preset in enumerate(self.presets[:self.preset_count]):
            offset = self.BANK_HEADER_SIZE + (i * self.PRESET_SIZE)
            preset_data = bytearray(self.PRESET_SIZE)
            preset_data[0:16] = preset["name"].encode('ascii')[:16]
            data.extend(preset_data)
        
        return bytes(data)
    
    def save(self, output_path: str) -> Dict[str, Any]:
        """Save bank to .EB2 file"""
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        
        data = self.to_bytes()
        
        with open(output_path, 'wb') as f:
            f.write(data)
        
        return {
            "file": str(output_path),
            "size": len(data),
            "presets": len(self.presets),
            "samples": len(self.samples)
        }


class BankTemplates:
    """Pre-defined bank templates"""
    
    @staticmethod
    def init_bank() -> BankTemplate:
        """Minimal INIT BANK (like standard tools creates on format)"""
        bank = BankTemplate("INIT BANK", preset_count=1)
        bank.add_preset("INIT", volume=127, pan=0, transpose=0)
        return bank
    
    @staticmethod
    def percussion_bank(name: str = "PERCUSSION") -> BankTemplate:
        """Percussion bank template (10 presets)"""
        bank = BankTemplate(name, preset_count=10)
        
        presets = [
            "Kick", "Snare", "Hi-Hat", "Tom 1", "Tom 2",
            "Crash", "Ride", "Clap", "Cowbell", "Perc"
        ]
        
        for preset_name in presets:
            bank.add_preset(preset_name, volume=127)
        
        return bank
    
    @staticmethod
    def bass_bank(name: str = "BASS") -> BankTemplate:
        """Bass bank template (20 presets)"""
        bank = BankTemplate(name, preset_count=20)
        
        presets = [
            "Analog Bass", "Synth Bass", "Sub Bass", "Acid Bass",
            "Fingered", "Slap Bass", "Picked", "Fretless",
            "Upright", "Acoustic", "Electric", "Moog Bass",
            "TB-303", "Wobble", "Reese", "Deep Bass",
            "Growl", "Pluck", "Tap", "Thumb"
        ]
        
        for preset_name in presets:
            bank.add_preset(preset_name, volume=120, transpose=-12)
        
        return bank
    
    @staticmethod
    def pad_bank(name: str = "PADS") -> BankTemplate:
        """Pad/string bank template (20 presets)"""
        bank = BankTemplate(name, preset_count=20)
        
        presets = [
            "String Pad", "Warm Pad", "Soft Pad", "Sweep Pad",
            "Choir Pad", "Bell Pad", "Glass Pad", "Synth Pad",
            "Analog Pad", "Digital Pad", "Space Pad", "Ambient",
            "Texture", "Atmosphere", "Drone", "Layer",
            "Evolving", "Moving", "Shimmer", "Wash"
        ]
        
        for preset_name in presets:
            bank.add_preset(preset_name, volume=110)
        
        return bank
    
    @staticmethod
    def lead_bank(name: str = "LEADS") -> BankTemplate:
        """Lead synth bank template (20 presets)"""
        bank = BankTemplate(name, preset_count=20)
        
        presets = [
            "Saw Lead", "Square Lead", "Sync Lead", "Pluck Lead",
            "Stab", "Trance Lead", "Arp Lead", "Sequence",
            "Mono Lead", "Detune Lead", "Octave Lead", "Fifth Lead",
            "Brass Lead", "String Lead", "Vocal Lead", "Bell Lead",
            "Resonant", "Filter Lead", "Modulated", "Vintage"
        ]
        
        for preset_name in presets:
            bank.add_preset(preset_name, volume=127)
        
        return bank
    
    @staticmethod
    def fx_bank(name: str = "FX") -> BankTemplate:
        """Sound effects bank template (30 presets)"""
        bank = BankTemplate(name, preset_count=30)
        
        presets = [
            "Noise", "Swoosh", "Impact", "Rise", "Fall",
            "Explosion", "Laser", "Zap", "Beep", "Glitch",
            "Vinyl Crackle", "Rain", "Wind", "Thunder", "Ocean",
            "Bird", "Animal", "Voice", "Breath", "Whisper",
            "Door", "Glass", "Metal", "Wood", "Stone",
            "Machine", "Digital", "Analog", "Retro", "Futuristic"
        ]
        
        for preset_name in presets:
            bank.add_preset(preset_name, volume=120)
        
        return bank
    
    @staticmethod
    def empty_bank(name: str = "EMPTY", preset_count: int = 100) -> BankTemplate:
        """Empty bank with placeholder presets"""
        bank = BankTemplate(name, preset_count=preset_count)
        
        for i in range(preset_count):
            bank.add_preset(f"Preset {i+1:03d}", volume=100)
        
        return bank
    
    @staticmethod
    def list_templates() -> List[Dict[str, Any]]:
        """List available templates"""
        return [
            {"name": "INIT BANK", "description": "Minimal single-preset bank", "presets": 1},
            {"name": "PERCUSSION", "description": "10 drum/percussion presets", "presets": 10},
            {"name": "BASS", "description": "20 bass synth presets", "presets": 20},
            {"name": "PADS", "description": "20 pad/string presets", "presets": 20},
            {"name": "LEADS", "description": "20 lead synth presets", "presets": 20},
            {"name": "FX", "description": "30 sound effect presets", "presets": 30},
            {"name": "EMPTY", "description": "Empty bank with placeholders", "presets": 100}
        ]
    
    @staticmethod
    def create(template_name: str, output_path: str, **kwargs) -> Dict[str, Any]:
        """Create bank from template
        
        Args:
            template_name: Template name (INIT, PERCUSSION, BASS, etc.)
            output_path: Output .EB2 file path
            **kwargs: Template-specific options (name, preset_count, etc.)
        
        Returns:
            {"file": str, "size": int, "presets": int, "samples": int}
        """
        template_name_upper = template_name.upper()
        
        # Select template
        if template_name_upper == "INIT" or template_name_upper == "INIT BANK":
            bank = BankTemplates.init_bank()
        elif template_name_upper == "PERCUSSION":
            bank = BankTemplates.percussion_bank(kwargs.get("name", "PERCUSSION"))
        elif template_name_upper == "BASS":
            bank = BankTemplates.bass_bank(kwargs.get("name", "BASS"))
        elif template_name_upper == "PADS" or template_name_upper == "PAD":
            bank = BankTemplates.pad_bank(kwargs.get("name", "PADS"))
        elif template_name_upper == "LEADS" or template_name_upper == "LEAD":
            bank = BankTemplates.lead_bank(kwargs.get("name", "LEADS"))
        elif template_name_upper == "FX":
            bank = BankTemplates.fx_bank(kwargs.get("name", "FX"))
        elif template_name_upper == "EMPTY":
            preset_count = kwargs.get("preset_count", 100)
            bank = BankTemplates.empty_bank(kwargs.get("name", "EMPTY"), preset_count)
        else:
            raise ValueError(f"Unknown template: {template_name}")
        
        return bank.save(output_path)
