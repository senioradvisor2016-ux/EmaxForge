#!/bin/bash
# Interactive Tooltip Test Script

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 EMAX FORGE TOOLTIP TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if app is running
if ! pgrep -f "EmaxForge" > /dev/null; then
    echo "❌ App not running. Starting now..."
    cd ~/clawd/EmaxForge && .build/release/EmaxForge &
    sleep 2
fi

echo "✅ App is running"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "INTERACTIVE TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to test a tooltip
test_tooltip() {
    local button_name="$1"
    local expected_tooltip="$2"
    
    echo "Testing: $button_name"
    echo "Expected tooltip: \"$expected_tooltip\""
    echo ""
    echo "👆 HOVER OVER THE $button_name BUTTON NOW"
    echo "   (You have 5 seconds)"
    echo ""
    
    for i in {5..1}; do
        echo -ne "   $i... \r"
        sleep 1
    done
    echo ""
    
    read -p "Did the tooltip appear? (y/n): " response
    if [[ "$response" == "y" ]]; then
        echo "✅ PASS: $button_name"
    else
        echo "❌ FAIL: $button_name"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Bring app to front
osascript -e 'tell application "System Events" to set frontmost of process "EmaxForge" to true' 2>/dev/null

echo "The EmaxForge window should now be in front."
echo "Look at the toolbar (top-right area of the window)."
echo ""
read -p "Press ENTER when ready to start testing..."
echo ""

# Test primary toolbar tooltips
test_tooltip "REFRESH (circular arrow icon)" "Refresh (⌘R)"
test_tooltip "OPEN FOLDER (folder icon)" "Open Folder (⌘O)"

echo ""
echo "Now click the '...' (three-dot) button in the toolbar."
echo "A dropdown menu should appear with more buttons."
echo ""
read -p "Press ENTER when the dropdown is open..."
echo ""

# Test secondary toolbar tooltips
test_tooltip "BATCH RENAME (in dropdown)" "Batch Rename (⌘⇧R)"
test_tooltip "CREATE BOOTABLE DISK (in dropdown)" "Create Bootable Disk (⌘⇧B)"
test_tooltip "KNOWLEDGE BASE (in dropdown)" "Knowledge Base (⌘⇧K)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If any tooltips failed, check:"
echo "  1. System Settings → Accessibility → Display → Show tooltips"
echo "  2. Hover for 1-2 seconds (tooltip has delay)"
echo "  3. Restart app: killall EmaxForge && .build/release/EmaxForge &"
echo ""
