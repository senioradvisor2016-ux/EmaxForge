#!/bin/bash
# Convert .EB2 files to native EMAX II format using EMXP

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.EB2> [output.raw]"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.EB2}.raw}"

# Cache directory
CACHE_DIR="$HOME/.emaxforge/bank_cache"
mkdir -p "$CACHE_DIR"

# Check cache first
INPUT_HASH=$(md5 -q "$INPUT")
CACHED="$CACHE_DIR/${INPUT_HASH}.raw"

if [ -f "$CACHED" ]; then
    echo "✅ Using cached conversion"
    cp "$CACHED" "$OUTPUT"
    echo "$OUTPUT"
    exit 0
fi

echo "🔄 Converting .EB2 → native format (via EMXP)..." >&2

# For now, direct integration will come later
# User must create disk with EMXP and extract banks manually
echo "⚠️  Automatic .EB2 conversion not yet available" >&2
echo "   Workaround: Import banks from EMXP-created .EZ2/.HDA disks" >&2
exit 1
