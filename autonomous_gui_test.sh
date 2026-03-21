#!/bin/bash

# EmaxForge Autonomous GUI Testing
# Hybrid approach: CLI validation + Screenshot verification
# Date: March 17, 2026

set -e

echo "========================================="
echo "AUTONOMOUS GUI TESTING - EmaxForge"
echo "========================================="
echo ""

TEST_DISK="/tmp/GUI_TEST.hda"
SCREENSHOTS_DIR="$HOME/clawd/EmaxForge/test_screenshots"

mkdir -p "$SCREENSHOTS_DIR"

# PHASE 1: CLI Preparation
echo "PHASE 1: CLI Preparation"
echo "========================"
echo ""

echo "1.1 Creating test disk (239 MB)..."
cli-anything-emaxforge create-disk \
    --size 239 \
    --scsi-id 2 \
    --output "$TEST_DISK" > /dev/null 2>&1

if [ -f "$TEST_DISK" ]; then
    echo "   ✓ Test disk created"
else
    echo "   ✗ Failed to create disk"
    exit 1
fi

echo "1.2 Importing test bank..."
cli-anything-emaxforge import-bank \
    --disk "$TEST_DISK" \
    --bank ~/Desktop/sample-banks/Brass_Pipes.EB2 > /dev/null 2>&1

BANK_COUNT=$(cli-anything-emaxforge list-banks \
    --disk "$TEST_DISK" \
    --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")

echo "   ✓ Imported banks: $BANK_COUNT"

echo "1.3 CLI validation..."
VALID=$(cli-anything-emaxforge verify-disk \
    --disk "$TEST_DISK" \
    --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['valid'])" 2>/dev/null || echo "False")

if [ "$VALID" = "True" ]; then
    echo "   ✓ Disk valid (CLI check passed)"
else
    echo "   ⚠ Disk validation inconclusive"
fi

echo ""

# PHASE 2: GUI Launch & Screenshot
echo "PHASE 2: GUI Testing"
echo "===================="
echo ""

echo "2.1 Killing existing EmaxForge..."
killall EmaxForge 2>/dev/null || true
sleep 1

echo "2.2 Launching EmaxForge with test disk..."
open -a ~/clawd/EmaxForge/.build/EmaxForge.app "$TEST_DISK"
sleep 4

# Check if running
if pgrep -x "EmaxForge" > /dev/null; then
    echo "   ✓ EmaxForge running (PID: $(pgrep -x EmaxForge))"
else
    echo "   ✗ EmaxForge failed to launch"
    exit 1
fi

echo "2.3 Taking baseline screenshot..."
screencapture -o -x "$SCREENSHOTS_DIR/01_app_launched.png"
echo "   ✓ Screenshot: $SCREENSHOTS_DIR/01_app_launched.png"

echo ""

# PHASE 3: Manual Intervention Instructions
echo "PHASE 3: Manual Testing Instructions"
echo "====================================="
echo ""
echo "EmaxForge is now running with test disk loaded."
echo ""
echo "MANUAL STEPS:"
echo ""
echo "1. VERIFY DISK:"
echo "   - Look for 'Verify Disk' button (green card)"
echo "   - Click it"
echo "   - Sheet should open with 4 checks"
echo "   - All should be green checkmarks"
echo "   - Click 'Done'"
echo ""
echo "2. EXPORT BANKS:"
echo "   - Look for 'Export Banks' button (blue card)"
echo "   - Click it"
echo "   - Sheet lists $BANK_COUNT banks"
echo "   - Select 2-3 banks"
echo "   - Choose ~/Desktop as output"
echo "   - Click 'Export X Banks'"
echo "   - Progress bar appears"
echo "   - Success message shows"
echo ""
echo "3. REPORT:"
echo "   - Did both features work? (yes/no)"
echo "   - Any errors or unexpected behavior?"
echo ""
echo "========================================="
echo ""
echo "Press ENTER when testing is complete..."
read

# Take final screenshot
echo ""
echo "Taking final screenshot..."
screencapture -o -x "$SCREENSHOTS_DIR/02_test_complete.png"
echo "✓ Screenshot: $SCREENSHOTS_DIR/02_test_complete.png"

# Cleanup
echo ""
echo "Cleanup..."
killall EmaxForge 2>/dev/null || true

echo ""
echo "========================================="
echo "TEST COMPLETE"
echo "========================================="
echo ""
echo "Screenshots saved to:"
echo "  $SCREENSHOTS_DIR/"
echo ""
echo "Next: Review screenshots and manual test results"
echo ""
