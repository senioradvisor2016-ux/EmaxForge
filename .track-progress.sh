#!/bin/bash
# Track Claude Code progress every 5 minutes

LAST_COUNT=7
INTERVAL=300  # 5 minutes

while true; do
    # Count new Swift files
    NEW_COUNT=$(find EmaxForge/Sources/Views -name "*.swift" -mmin -20 2>/dev/null | wc -l | tr -d ' ')
    
    # Get latest modified files
    LATEST=$(find EmaxForge/Sources/Views -name "*.swift" -mmin -5 2>/dev/null | sort -t/ -k5)
    
    if [ "$NEW_COUNT" -gt "$LAST_COUNT" ]; then
        echo "🎯 Progress: $NEW_COUNT/9 files complete (+$((NEW_COUNT - LAST_COUNT)))"
        echo "Latest:"
        echo "$LATEST" | while read f; do
            echo "  ✅ $(basename $f)"
        done
        LAST_COUNT=$NEW_COUNT
    fi
    
    # Check if process still running
    if ! ps -p 14172 > /dev/null 2>&1; then
        echo "✅ Claude Code finished!"
        break
    fi
    
    sleep $INTERVAL
done
