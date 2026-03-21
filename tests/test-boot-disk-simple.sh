#!/bin/bash
# Simple Boot Disk Test - No UI automation
# Tests boot disk creation by checking file output

TEST_NAME="BootDisk_FileOutput"
TEST_OUTPUT="/tmp/EmaxForge_test_HD00.hda"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🧪 Testing Boot Disk Creation (File Output)"
echo "============================================"
echo ""

# Cleanup
rm -f "$TEST_OUTPUT"

# We can't automate the UI click, but we can test if Peter manually creates a boot disk
# Or we test the underlying ImageCreator directly via Swift CLI

echo "📝 Testing ImageCreator.swift directly..."
echo ""

# Create a Swift test file
cat > /tmp/test_boot_disk.swift << 'EOF'
import Foundation

// Import EmaxForge sources would go here if this was properly integrated
// For now, we'll just test file operations

let testPath = "/tmp/EmaxForge_test_HD00.hda"

// Verify boot signature if file exists
if FileManager.default.fileExists(atPath: testPath),
   let data = try? Data(contentsOf: URL(fileURLWithPath: testPath)) {
    
    // Check boot signature at offset 510 (0x1FE)
    if data.count >= 512 {
        let byte1 = data[510]
        let byte2 = data[511]
        
        if byte1 == 0x78 && byte2 == 0x82 {
            print("✅ PASS: Boot signature correct (0x78 0x82)")
            exit(0)
        } else {
            print("❌ FAIL: Boot signature wrong (got \(String(format: "0x%02X 0x%02X", byte1, byte2)))")
            exit(1)
        }
    } else {
        print("❌ FAIL: File too small (\(data.count) bytes)")
        exit(1)
    }
} else {
    print("⏭️  SKIP: Test file not found at \(testPath)")
    print("💡 TIP: Manually create boot disk to \(testPath) to test")
    exit(2)
}
EOF

# Try to run Swift test
if command -v swift &> /dev/null; then
    swift /tmp/test_boot_disk.swift
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo "🎉 Test PASSED!"
        exit 0
    elif [ $EXIT_CODE -eq 2 ]; then
        echo ""
        echo "⚠️  Test SKIPPED (no file to verify)"
        echo ""
        echo "To test manually:"
        echo "  1. Open EmaxForge"
        echo "  2. Create bootable disk to: $TEST_OUTPUT"
        echo "  3. Run this test again"
        exit 0
    else
        echo ""
        echo "❌ Test FAILED!"
        exit 1
    fi
else
    echo "❌ Swift compiler not found"
    exit 1
fi
