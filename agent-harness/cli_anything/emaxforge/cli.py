#!/usr/bin/env python3
"""
CLI-Anything harness for EmaxForge
Autonomous backend for SwiftUI integration
"""

import sys
import json
import argparse
from pathlib import Path

# Import handlers
sys.path.insert(0, str(Path(__file__).parent))
from handlers.audio_converter import AudioConverter
from core.disk import validate_boot


def handle_convert_audio(args):
    """Convert audio with advanced options"""
    converter = AudioConverter()
    
    result = converter.convert_advanced(
        args.input,
        args.output,
        target_rate=args.rate,
        mono=args.mono,
        normalize=args.normalize
    )
    
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"✅ Converted: {result['input']} → {result['output']}")
        if result['input_rate'] != result['output_rate']:
            print(f"   Rate: {result['input_rate']} → {result['output_rate']} Hz")
        print(f"   Channels: {result['channels']}")
    
    return 0


def handle_validate_boot(args):
    """Validate that a .hda image is bootable on EMAX II"""
    result = validate_boot(args.disk)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        # Human-readable output
        print(f"Boot Disk Validator: {args.disk}\n")
        for check in result["checks"]:
            icon = "✅" if check["passed"] else "❌"
            print(f"  {icon} {check['name']}: {check['message']}")
        print(f"\n{result['summary']}")

    # Exit code: 0 = bootable, 1 = not bootable
    return 0 if result["bootable"] else 1


def main():
    parser = argparse.ArgumentParser(
        prog='cli-anything-emaxforge',
        description='CLI-Anything harness for EmaxForge'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # validate-boot command
    boot_parser = subparsers.add_parser(
        'validate-boot',
        help='Validate .hda image is bootable on EMAX II before writing to SD card'
    )
    boot_parser.add_argument('disk', help='Path to .hda disk image')
    boot_parser.add_argument('--json', action='store_true', help='JSON output')
    boot_parser.set_defaults(func=handle_validate_boot)

    # convert-audio command
    convert_parser = subparsers.add_parser('convert-audio', help='Convert audio file')
    convert_parser.add_argument('input', help='Input audio file (WAV/AIFF)')
    convert_parser.add_argument('output', help='Output WAV file')
    convert_parser.add_argument('--rate', type=int, default=42000, help='Target sample rate')
    convert_parser.add_argument('--mono', action='store_true', help='Convert to mono')
    convert_parser.add_argument('--normalize', action='store_true', help='Normalize volume')
    convert_parser.add_argument('--json', action='store_true', help='JSON output')
    convert_parser.set_defaults(func=handle_convert_audio)
    
    # Parse and execute
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        return args.func(args)
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
