#!/usr/bin/env python3
"""
Advanced audio conversion for format compatibility
Supports: AIFF, WAV, rate conversion, bit depth, stereo→mono, normalize
"""

import sys
import json
import wave
import struct
import math
from pathlib import Path

# For AIFF parsing (optional, fallback to ffmpeg)
try:
    import aifc
    HAS_AIFC = True
except ImportError:
    HAS_AIFC = False
    print("Warning: aifc not available, using ffmpeg for AIFF", file=sys.stderr)

# For resampling (if available, fallback to simple interpolation)
try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False
    print("Warning: numpy not available, using basic resampling", file=sys.stderr)


class AudioConverter:
    """compatible audio conversion"""
    
    EMAX_RATE = 42000  # EMAX II sample rate
    EMAX_BITS = 16     # EMAX II bit depth
    
    def load_wav(self, path):
        """Load WAV file"""
        with wave.open(str(path), 'rb') as wav:
            params = wav.getparams()
            frames = wav.readframes(params.nframes)
            
            # Parse samples
            if params.sampwidth == 1:
                samples = struct.unpack(f'{params.nframes * params.nchannels}B', frames)
                # Convert unsigned 8-bit to signed 16-bit
                samples = [(s - 128) * 256 for s in samples]
            elif params.sampwidth == 2:
                samples = struct.unpack(f'{params.nframes * params.nchannels}h', frames)
            elif params.sampwidth == 3:
                # 24-bit (3 bytes per sample)
                samples = []
                for i in range(0, len(frames), 3 * params.nchannels):
                    for ch in range(params.nchannels):
                        offset = i + (ch * 3)
                        # Little-endian 24-bit
                        val = struct.unpack('<i', frames[offset:offset+3] + b'\x00')[0] >> 8
                        samples.append(val // 256)  # Convert to 16-bit
            else:
                raise ValueError(f"Unsupported bit depth: {params.sampwidth * 8}")
            
            return {
                'rate': params.framerate,
                'channels': params.nchannels,
                'bits': params.sampwidth * 8,
                'frames': params.nframes,
                'samples': samples
            }
    
    def load_aiff(self, path):
        """Load AIFF/AIFC file"""
        if not HAS_AIFC:
            # Fallback: convert via ffmpeg
            import subprocess
            import tempfile
            
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
                tmp_path = tmp.name
            
            subprocess.run([
                'ffmpeg', '-i', str(path),
                '-ar', '44100', '-ac', '2', '-sample_fmt', 's16',
                tmp_path, '-y'
            ], capture_output=True)
            
            audio = self.load_wav(tmp_path)
            Path(tmp_path).unlink()
            return audio
        
        with aifc.open(str(path), 'rb') as aiff:
            params = aiff.getparams()
            frames = aiff.readframes(params.nframes)
            
            # AIFF is big-endian
            if params.sampwidth == 1:
                samples = struct.unpack(f'>{params.nframes * params.nchannels}b', frames)
                samples = [s * 256 for s in samples]
            elif params.sampwidth == 2:
                samples = struct.unpack(f'>{params.nframes * params.nchannels}h', frames)
            elif params.sampwidth == 3:
                samples = []
                for i in range(0, len(frames), 3 * params.nchannels):
                    for ch in range(params.nchannels):
                        offset = i + (ch * 3)
                        val = struct.unpack('>i', b'\x00' + frames[offset:offset+3])[0] >> 8
                        samples.append(val // 256)
            else:
                raise ValueError(f"Unsupported bit depth: {params.sampwidth * 8}")
            
            return {
                'rate': params.framerate,
                'channels': params.nchannels,
                'bits': params.sampwidth * 8,
                'frames': params.nframes,
                'samples': samples
            }
    
    def resample(self, audio, target_rate):
        """Resample audio to target rate"""
        if audio['rate'] == target_rate:
            return audio
        
        ratio = target_rate / audio['rate']
        new_frames = int(audio['frames'] * ratio)
        
        if HAS_NUMPY:
            # High-quality resampling with numpy
            samples = np.array(audio['samples'])
            channels = audio['channels']
            
            if channels == 1:
                resampled = np.interp(
                    np.linspace(0, len(samples) - 1, new_frames),
                    np.arange(len(samples)),
                    samples
                )
            else:
                # Interleaved stereo
                left = samples[0::2]
                right = samples[1::2]
                
                left_resampled = np.interp(
                    np.linspace(0, len(left) - 1, new_frames),
                    np.arange(len(left)),
                    left
                )
                right_resampled = np.interp(
                    np.linspace(0, len(right) - 1, new_frames),
                    np.arange(len(right)),
                    right
                )
                
                # Re-interleave
                resampled = np.empty(new_frames * 2, dtype=left_resampled.dtype)
                resampled[0::2] = left_resampled
                resampled[1::2] = right_resampled
            
            audio['samples'] = resampled.astype(int).tolist()
        else:
            # Basic linear interpolation
            samples = audio['samples']
            resampled = []
            
            for i in range(new_frames * audio['channels']):
                pos = i / ratio
                idx = int(pos)
                frac = pos - idx
                
                if idx + 1 < len(samples):
                    val = samples[idx] * (1 - frac) + samples[idx + 1] * frac
                else:
                    val = samples[idx]
                
                resampled.append(int(val))
            
            audio['samples'] = resampled
        
        audio['rate'] = target_rate
        audio['frames'] = new_frames
        
        return audio
    
    def stereo_to_mono(self, audio):
        """Convert stereo to mono (average channels)"""
        if audio['channels'] == 1:
            return audio
        
        samples = audio['samples']
        mono = []
        
        for i in range(0, len(samples), 2):
            left = samples[i]
            right = samples[i + 1] if i + 1 < len(samples) else left
            mono.append((left + right) // 2)
        
        audio['samples'] = mono
        audio['channels'] = 1
        audio['frames'] = len(mono)
        
        return audio
    
    def normalize(self, audio, peak_db=-0.1):
        """Normalize audio to peak level"""
        samples = audio['samples']
        
        # Find peak
        peak = max(abs(s) for s in samples)
        
        if peak == 0:
            return audio
        
        # Calculate gain (dB to linear)
        target = int(32767 * (10 ** (peak_db / 20)))
        gain = target / peak
        
        # Apply gain
        audio['samples'] = [int(min(32767, max(-32768, s * gain))) for s in samples]
        
        return audio
    
    def save_wav(self, audio, path):
        """Save as WAV file"""
        with wave.open(str(path), 'wb') as wav:
            wav.setnchannels(audio['channels'])
            wav.setsampwidth(2)  # 16-bit
            wav.setframerate(audio['rate'])
            wav.setnframes(audio['frames'])
            
            # Pack samples
            frames = struct.pack(f'{len(audio["samples"])}h', *audio['samples'])
            wav.writeframes(frames)
    
    def convert_advanced(self, input_path, output_path, 
                        target_rate=None, mono=False, normalize=False):
        """All-in-one conversion pipeline"""
        
        input_path = Path(input_path)
        output_path = Path(output_path)
        
        # 1. Load (auto-detect format)
        if input_path.suffix.lower() in ['.aiff', '.aif']:
            audio = self.load_aiff(input_path)
        else:
            audio = self.load_wav(input_path)
        
        # 2. Rate conversion
        if target_rate and audio['rate'] != target_rate:
            audio = self.resample(audio, target_rate)
        
        # 3. Stereo → Mono
        if mono:
            audio = self.stereo_to_mono(audio)
        
        # 4. Normalize
        if normalize:
            audio = self.normalize(audio)
        
        # 5. Save
        self.save_wav(audio, output_path)
        
        return {
            'success': True,
            'input': str(input_path),
            'output': str(output_path),
            'input_rate': audio['rate'],
            'output_rate': target_rate or audio['rate'],
            'channels': audio['channels'],
            'frames': audio['frames']
        }


def main():
    """CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Advanced audio conversion for standard tools')
    parser.add_argument('input', help='Input audio file (WAV or AIFF)')
    parser.add_argument('output', help='Output WAV file')
    parser.add_argument('--target-rate', type=int, default=42000, help='Target sample rate (default: 42000)')
    parser.add_argument('--mono', action='store_true', help='Convert to mono')
    parser.add_argument('--normalize', action='store_true', help='Normalize volume')
    parser.add_argument('--json', action='store_true', help='Output JSON')
    
    args = parser.parse_args()
    
    try:
        converter = AudioConverter()
        result = converter.convert_advanced(
            args.input,
            args.output,
            target_rate=args.target_rate,
            mono=args.mono,
            normalize=args.normalize
        )
        
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"✅ Converted: {args.input} → {args.output}")
            print(f"   Rate: {result['input_rate']} → {result['output_rate']} Hz")
            print(f"   Channels: {result['channels']}")
            print(f"   Frames: {result['frames']}")
        
        return 0
    
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
