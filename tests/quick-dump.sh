#!/bin/bash
# Quick UI Dump - For debugging UI accessibility
# Usage: ./quick-dump.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "📸 Capturing EmaxForge UI tree..."
echo ""

osascript "$SCRIPT_DIR/applescript/dump-ui.applescript"

echo ""
echo "✅ UI dump saved to: $SCRIPT_DIR/logs/ui-dump.txt"
echo ""
echo "View with:"
echo "  cat ~/clawd/EmaxForge/tests/logs/ui-dump.txt"
echo "  less ~/clawd/EmaxForge/tests/logs/ui-dump.txt"
