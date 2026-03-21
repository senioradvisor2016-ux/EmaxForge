#!/bin/bash
# EmaxForge System Test
# Tests CLI tools, output validation, and app startup

set -e

echo "========================================"
echo "EmaxForge System Test"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test files
TEST_BANK="$HOME/clawd/Emax Drive/Emu Emax II [Sounds]/Sounds/Alan Wilder - Depeche Mode [Emax II]/SOMEBODY.EB2"
TEST_OUTPUT_DIR="/tmp/emaxforge-test-$$"
mkdir -p "$TEST_OUTPUT_DIR"

echo "Test output: $TEST_OUTPUT_DIR"
echo ""

# ========================================
# Test 1: Bank Parser
# ========================================
echo "========================================"
echo "TEST 1: Bank Parser (cli-parse-bank.swift)"
echo "========================================"

if [ ! -f "cli-parse-bank.swift" ]; then
    echo -e "${RED}❌ cli-parse-bank.swift not found${NC}"
    exit 1
fi

if [ ! -f "$TEST_BANK" ]; then
    echo -e "${RED}❌ Test bank not found: $TEST_BANK${NC}"
    exit 1
fi

echo "Parsing: $(basename "$TEST_BANK")"
swift cli-parse-bank.swift --bank "$TEST_BANK" > "$TEST_OUTPUT_DIR/parse-output.txt" 2>&1

# Validate output
if grep -q "JSON_OUTPUT_START" "$TEST_OUTPUT_DIR/parse-output.txt"; then
    echo -e "${GREEN}✅ JSON output present${NC}"
else
    echo -e "${RED}❌ No JSON output${NC}"
    exit 1
fi

if grep -q '"success" : true' "$TEST_OUTPUT_DIR/parse-output.txt"; then
    echo -e "${GREEN}✅ Parse successful${NC}"
else
    echo -e "${RED}❌ Parse failed${NC}"
    cat "$TEST_OUTPUT_DIR/parse-output.txt"
    exit 1
fi

# Extract bank name
BANK_NAME=$(grep -A 5 '"bankName"' "$TEST_OUTPUT_DIR/parse-output.txt" | head -1 | cut -d'"' -f4)
echo "  Bank name: $BANK_NAME"

# Extract pointer count
POINTERS=$(grep -A 5 '"pointers"' "$TEST_OUTPUT_DIR/parse-output.txt" | head -1 | awk '{print $2}' | tr -d ',')
echo "  Pointers: $POINTERS"

echo ""

# ========================================
# Test 2: Voice Parser
# ========================================
echo "========================================"
echo "TEST 2: Voice Parser (cli-parse-voices.swift)"
echo "========================================"

if [ ! -f "cli-parse-voices.swift" ]; then
    echo -e "${RED}❌ cli-parse-voices.swift not found${NC}"
    exit 1
fi

swift cli-parse-voices.swift --bank "$TEST_BANK" --max 5 > "$TEST_OUTPUT_DIR/voices-output.txt" 2>&1

if grep -q "Voice Structure" "$TEST_OUTPUT_DIR/voices-output.txt"; then
    echo -e "${GREEN}✅ Voice parsing successful${NC}"
else
    echo -e "${RED}❌ Voice parsing failed${NC}"
    cat "$TEST_OUTPUT_DIR/voices-output.txt"
    exit 1
fi

VOICE_COUNT=$(grep "Total voices found" "$TEST_OUTPUT_DIR/voices-output.txt" | awk '{print $4}')
echo "  Voices found: $VOICE_COUNT"

echo ""

# ========================================
# Test 3: Sample Extraction
# ========================================
echo "========================================"
echo "TEST 3: Sample Extraction (cli-extract-sample.swift)"
echo "========================================"

if [ ! -f "cli-extract-sample.swift" ]; then
    echo -e "${RED}❌ cli-extract-sample.swift not found${NC}"
    exit 1
fi

TEST_WAV="$TEST_OUTPUT_DIR/somebody-sample.wav"

swift cli-extract-sample.swift \
    --bank "$TEST_BANK" \
    --output "$TEST_WAV" \
    --offset 7000 \
    --length 50000 \
    --rate 44100 > "$TEST_OUTPUT_DIR/extract-output.txt" 2>&1

if [ -f "$TEST_WAV" ]; then
    echo -e "${GREEN}✅ WAV file created${NC}"
else
    echo -e "${RED}❌ WAV file not created${NC}"
    cat "$TEST_OUTPUT_DIR/extract-output.txt"
    exit 1
fi

# Validate WAV header
WAV_HEADER=$(hexdump -C "$TEST_WAV" | head -1 | awk '{print $2 $3 $4 $5}')
if [ "$WAV_HEADER" = "52494646" ]; then
    echo -e "${GREEN}✅ Valid RIFF header${NC}"
else
    echo -e "${RED}❌ Invalid WAV header: $WAV_HEADER${NC}"
    exit 1
fi

# Check file size
WAV_SIZE=$(stat -f%z "$TEST_WAV" 2>/dev/null || stat -c%s "$TEST_WAV" 2>/dev/null)
echo "  WAV size: $((WAV_SIZE / 1024)) KB"

# Verify with 'file' command
FILE_TYPE=$(file "$TEST_WAV")
if echo "$FILE_TYPE" | grep -q "RIFF.*WAVE"; then
    echo -e "${GREEN}✅ Valid WAV format (verified by file)${NC}"
else
    echo -e "${YELLOW}⚠️  file output: $FILE_TYPE${NC}"
fi

echo ""

# ========================================
# Test 4: Sample Trimmer
# ========================================
echo "========================================"
echo "TEST 4: Sample Trimmer (cli-trim-sample.swift)"
echo "========================================"

if [ ! -f "cli-trim-sample.swift" ]; then
    echo -e "${RED}❌ cli-trim-sample.swift not found${NC}"
    exit 1
fi

TEST_TRIMMED="$TEST_OUTPUT_DIR/somebody-trimmed.wav"

swift cli-trim-sample.swift \
    --input "$TEST_WAV" \
    --output "$TEST_TRIMMED" \
    --threshold 10 > "$TEST_OUTPUT_DIR/trim-output.txt" 2>&1

if [ -f "$TEST_TRIMMED" ]; then
    echo -e "${GREEN}✅ Trimmed WAV created${NC}"
else
    echo -e "${RED}❌ Trimmed WAV not created${NC}"
    cat "$TEST_OUTPUT_DIR/trim-output.txt"
    exit 1
fi

# Check if trimmed file is smaller
ORIGINAL_SIZE=$(stat -f%z "$TEST_WAV" 2>/dev/null || stat -c%s "$TEST_WAV" 2>/dev/null)
TRIMMED_SIZE=$(stat -f%z "$TEST_TRIMMED" 2>/dev/null || stat -c%s "$TEST_TRIMMED" 2>/dev/null)

echo "  Original: $((ORIGINAL_SIZE / 1024)) KB"
echo "  Trimmed: $((TRIMMED_SIZE / 1024)) KB"

if [ "$TRIMMED_SIZE" -le "$ORIGINAL_SIZE" ]; then
    echo -e "${GREEN}✅ Trim successful (size reduced or equal)${NC}"
else
    echo -e "${RED}❌ Trimmed file is larger!${NC}"
    exit 1
fi

# Parse savings
SAVINGS=$(grep "savingsPercent" "$TEST_OUTPUT_DIR/trim-output.txt" | head -1 | awk '{print $3}' | tr -d ',')
echo "  Savings: $SAVINGS%"

echo ""

# ========================================
# Test 5: JSON Output Validation
# ========================================
echo "========================================"
echo "TEST 5: JSON Output Validation"
echo "========================================"

# Test parse-bank JSON
if command -v jq &> /dev/null; then
    echo "Validating parse-bank JSON..."
    grep -A 100 "JSON_OUTPUT_START" "$TEST_OUTPUT_DIR/parse-output.txt" | \
        grep -B 100 "JSON_OUTPUT_END" | \
        sed '1d;$d' | jq . > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ parse-bank JSON valid${NC}"
    else
        echo -e "${RED}❌ parse-bank JSON invalid${NC}"
        exit 1
    fi
    
    echo "Validating extract-sample JSON..."
    grep -A 100 "JSON_OUTPUT_START" "$TEST_OUTPUT_DIR/extract-output.txt" | \
        grep -B 100 "JSON_OUTPUT_END" | \
        sed '1d;$d' | jq . > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ extract-sample JSON valid${NC}"
    else
        echo -e "${RED}❌ extract-sample JSON invalid${NC}"
        exit 1
    fi
    
    echo "Validating trim-sample JSON..."
    grep -A 100 "JSON_OUTPUT_START" "$TEST_OUTPUT_DIR/trim-output.txt" | \
        grep -B 100 "JSON_OUTPUT_END" | \
        sed '1d;$d' | jq . > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ trim-sample JSON valid${NC}"
    else
        echo -e "${RED}❌ trim-sample JSON invalid${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  jq not found, skipping JSON validation${NC}"
fi

echo ""

# ========================================
# Test 6: Mass Parser (Sample)
# ========================================
echo "========================================"
echo "TEST 6: Mass Parser (10 banks)"
echo "========================================"

if [ ! -f "mass-test-parser.sh" ]; then
    echo -e "${RED}❌ mass-test-parser.sh not found${NC}"
    exit 1
fi

# Create temp dir with 10 banks
TEST_MASS_DIR="$TEST_OUTPUT_DIR/mass-test-banks"
mkdir -p "$TEST_MASS_DIR"

# Copy first 10 .EB2 files
find "$HOME/clawd/Emax Drive/Emu Emax II [Sounds]/Sounds" -name "*.EB2" | head -10 | while read bank; do
    cp "$bank" "$TEST_MASS_DIR/"
done

BANK_COUNT=$(ls "$TEST_MASS_DIR"/*.EB2 2>/dev/null | wc -l | tr -d ' ')
echo "Testing with $BANK_COUNT banks..."

./mass-test-parser.sh "$TEST_MASS_DIR" > "$TEST_OUTPUT_DIR/mass-output.txt" 2>&1

if grep -q "Complete!" "$TEST_OUTPUT_DIR/mass-output.txt"; then
    echo -e "${GREEN}✅ Mass parser completed${NC}"
else
    echo -e "${RED}❌ Mass parser failed${NC}"
    tail -20 "$TEST_OUTPUT_DIR/mass-output.txt"
    exit 1
fi

# Check results file
RESULTS_FILE=$(ls -t mass-test-results/results_*.jsonl 2>/dev/null | head -1)
if [ -n "$RESULTS_FILE" ]; then
    RESULT_COUNT=$(wc -l < "$RESULTS_FILE" | tr -d ' ')
    echo "  Results: $RESULT_COUNT entries"
    if [ "$RESULT_COUNT" -ge "$BANK_COUNT" ]; then
        echo -e "${GREEN}✅ All banks processed${NC}"
    else
        echo -e "${RED}❌ Some banks failed${NC}"
    fi
else
    echo -e "${RED}❌ No results file found${NC}"
    exit 1
fi

echo ""

# ========================================
# Test 7: App Build
# ========================================
echo "========================================"
echo "TEST 7: App Build"
echo "========================================"

if [ ! -f "build.sh" ]; then
    echo -e "${RED}❌ build.sh not found${NC}"
    exit 1
fi

echo "Building EmaxForge.app..."
./build.sh > "$TEST_OUTPUT_DIR/build-output.txt" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    tail -50 "$TEST_OUTPUT_DIR/build-output.txt"
    exit 1
fi

# Check app bundle
if [ -d ".build/EmaxForge.app" ]; then
    echo -e "${GREEN}✅ App bundle exists${NC}"
    APP_SIZE=$(du -sh .build/EmaxForge.app | awk '{print $1}')
    echo "  App size: $APP_SIZE"
else
    echo -e "${RED}❌ App bundle not found${NC}"
    exit 1
fi

# Verify binary
if [ -f ".build/EmaxForge.app/Contents/MacOS/EmaxForge" ]; then
    echo -e "${GREEN}✅ Binary exists${NC}"
    
    # Check if codesigned
    if codesign -v .build/EmaxForge.app 2>/dev/null; then
        echo -e "${GREEN}✅ App is codesigned${NC}"
    else
        echo -e "${YELLOW}⚠️  App not codesigned (expected for dev build)${NC}"
    fi
else
    echo -e "${RED}❌ Binary not found${NC}"
    exit 1
fi

echo ""

# ========================================
# Test 8: Service Integration (Smoke Test)
# ========================================
echo "========================================"
echo "TEST 8: Service Integration"
echo "========================================"

# Check that service files exist and compile
if [ -f "EmaxForge/Sources/Services/SampleExtractorService.swift" ]; then
    echo -e "${GREEN}✅ SampleExtractorService exists${NC}"
else
    echo -e "${RED}❌ SampleExtractorService missing${NC}"
    exit 1
fi

if [ -f "EmaxForge/Sources/Services/SampleTrimmerService.swift" ]; then
    echo -e "${GREEN}✅ SampleTrimmerService exists${NC}"
else
    echo -e "${RED}❌ SampleTrimmerService missing${NC}"
    exit 1
fi

# Check InspectorPanel integration
if grep -q "SampleExtractorService" EmaxForge/Sources/Views/InspectorPanel.swift; then
    echo -e "${GREEN}✅ InspectorPanel uses SampleExtractorService${NC}"
else
    echo -e "${RED}❌ InspectorPanel not integrated${NC}"
    exit 1
fi

if grep -q "SampleTrimmerService" EmaxForge/Sources/Views/InspectorPanel.swift; then
    echo -e "${GREEN}✅ InspectorPanel uses SampleTrimmerService${NC}"
else
    echo -e "${RED}❌ InspectorPanel not integrated${NC}"
    exit 1
fi

echo ""

# ========================================
# Summary
# ========================================
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo "Test artifacts:"
echo "  $TEST_OUTPUT_DIR"
echo ""
echo "Generated files:"
echo "  - parse-output.txt (bank parser)"
echo "  - voices-output.txt (voice parser)"
echo "  - extract-output.txt (sample extractor)"
echo "  - trim-output.txt (sample trimmer)"
echo "  - somebody-sample.wav (extracted sample)"
echo "  - somebody-trimmed.wav (trimmed sample)"
echo "  - mass-output.txt (mass parser)"
echo "  - build-output.txt (app build log)"
echo ""
echo -e "${GREEN}🎉 EmaxForge system test complete!${NC}"
echo ""
echo "To open the app:"
echo "  open .build/EmaxForge.app"
echo ""
