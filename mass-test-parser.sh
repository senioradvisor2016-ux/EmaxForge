#!/bin/bash
# Mass-test .EB2 parser against large collection
# Usage: ./mass-test-parser.sh <directory>

set -e

BANK_DIR="${1:-$HOME/clawd/Emax vs Claude/Universe of Sounds 1}"
OUTPUT_DIR="./mass-test-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$OUTPUT_DIR/results_$TIMESTAMP.jsonl"
STATS_FILE="$OUTPUT_DIR/stats_$TIMESTAMP.txt"

# Create output dir
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "EmaxForge Mass Parser Test"
echo "=========================================="
echo "Target: $BANK_DIR"
echo "Output: $RESULTS_FILE"
echo ""

# Count total banks
TOTAL=$(find "$BANK_DIR" -name "*.EB2" -o -name "*.eb2" | wc -l | tr -d ' ')
echo "📦 Found $TOTAL banks"
echo ""

# Progress tracking
PROCESSED=0
SUCCESS=0
FAILED=0

# Process each bank
find "$BANK_DIR" -name "*.EB2" -o -name "*.eb2" | while read -r bank; do
    PROCESSED=$((PROCESSED + 1))
    
    # Show progress every 50 banks
    if [ $((PROCESSED % 50)) -eq 0 ]; then
        echo "[$PROCESSED/$TOTAL] Processing..."
    fi
    
    # Parse bank
    RESULT=$(swift cli-parse-bank.swift --bank "$bank" 2>&1)
    
    # Extract JSON
    JSON=$(echo "$RESULT" | sed -n '/JSON_OUTPUT_START/,/JSON_OUTPUT_END/p' | grep -v "JSON_OUTPUT")
    
    if [ -n "$JSON" ]; then
        # Add filename to JSON
        FILENAME=$(basename "$bank")
        echo "$JSON" | jq --arg file "$FILENAME" '. + {filename: $file}' >> "$RESULTS_FILE"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "❌ Failed: $bank" >&2
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=========================================="
echo "✅ Complete!"
echo "=========================================="
echo "Total: $TOTAL"
echo "Success: $SUCCESS"
echo "Failed: $FAILED"
echo ""

# Generate statistics
echo "📊 Generating statistics..."

cat > "$STATS_FILE" << EOF
EmaxForge Mass Parser Test Results
==================================
Timestamp: $TIMESTAMP
Target: $BANK_DIR
Total banks: $TOTAL
Success: $SUCCESS
Failed: $FAILED

Statistics:
-----------

EOF

# Pointer count distribution
echo "Pointer Count Distribution:" >> "$STATS_FILE"
jq -r '.pointers' "$RESULTS_FILE" | sort -n | uniq -c | sort -rn >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

# File size distribution
echo "File Size Distribution (MB):" >> "$STATS_FILE"
jq -r '(.size / 1048576 | floor)' "$RESULTS_FILE" | sort -n | uniq -c | sort -rn | head -20 >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

# Most common names
echo "Most Common Bank Names (top 20):" >> "$STATS_FILE"
jq -r '.bankName' "$RESULTS_FILE" | sort | uniq -c | sort -rn | head -20 >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

# Edge cases (no pointers)
echo "Banks with 0 pointers:" >> "$STATS_FILE"
jq -r 'select(.pointers == 0) | .filename' "$RESULTS_FILE" >> "$STATS_FILE"
echo "" >> "$STATS_FILE"

# Largest banks
echo "Largest Banks (top 10):" >> "$STATS_FILE"
jq -r '[.filename, .size] | @tsv' "$RESULTS_FILE" | sort -k2 -rn | head -10 >> "$STATS_FILE"

echo ""
echo "📄 Results: $RESULTS_FILE"
echo "📊 Stats: $STATS_FILE"
echo ""
echo "View stats: cat $STATS_FILE"
echo "Query data: jq . $RESULTS_FILE | less"
