#!/bin/bash
# Development Loop - EmaxForge + CLI-Anything
# 
# Usage:
#   ./dev-loop-cli-anything.sh <feature>
#
# Example:
#   ./dev-loop-cli-anything.sh disk-create

set -e

FEATURE="${1:-disk-create}"
EMAXFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$EMAXFORGE_ROOT/agent-harness"
CLI="$HARNESS_DIR/emaxforge-cli"

echo "============================================"
echo "EmaxForge Development Loop"
echo "============================================"
echo "Feature: $FEATURE"
echo "Repo: $EMAXFORGE_ROOT"
echo ""

# Step 1: Check CLI harness installed
if [ ! -x "$CLI" ]; then
    echo "⚠️  CLI harness not installed"
    echo "Installing..."
    cd "$HARNESS_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install -e .
    chmod +x emaxforge-cli
    echo "✅ Harness installed"
fi

# Step 2: Build EmaxForge.app
echo ""
echo "📦 Building EmaxForge.app..."
cd "$EMAXFORGE_ROOT"
./build.sh || {
    echo "❌ Build failed"
    exit 1
}
echo "✅ Build successful"

# Step 3: Run CLI test for feature
echo ""
echo "🧪 Testing feature: $FEATURE"

case "$FEATURE" in
    disk-create)
        echo "Testing disk creation..."
        $CLI --json disk create --size 239 --boot --output /tmp/test-boot.hda
        $CLI disk info --input /tmp/test-boot.hda || echo "(info not implemented yet)"
        ;;
    
    bank-import)
        echo "Testing bank import..."
        # Create test disk first
        $CLI disk create --size 239 --output /tmp/test-disk.hda
        # Try to import bank
        $CLI bank import --disk /tmp/test-disk.hda --bank test.EB2
        ;;
    
    sample-convert)
        echo "Testing sample conversion..."
        $CLI sample convert --input test.wav --output /tmp/test-disk.hda
        ;;
    
    *)
        echo "⚠️  Unknown feature: $FEATURE"
        echo "Available: disk-create, bank-import, sample-convert"
        exit 1
        ;;
esac

# Step 4: Launch UI for manual verification
echo ""
echo "🎨 Launching EmaxForge for manual verification..."
open "$EMAXFORGE_ROOT/.build/EmaxForge.app"
sleep 2

# Step 5: Screenshot
echo ""
echo "📸 Taking screenshot..."
screencapture -w "$EMAXFORGE_ROOT/screenshots/dev-loop-$FEATURE-$(date +%Y%m%d_%H%M%S).png"
echo "Screenshot saved"

# Step 6: Summary
echo ""
echo "============================================"
echo "Dev Loop Complete"
echo "============================================"
echo "Next steps:"
echo "1. Verify UI screenshot"
echo "2. Implement missing backend in swift_backend.py"
echo "3. Update Swift CLI scripts if needed"
echo "4. Run loop again to verify"
echo ""
