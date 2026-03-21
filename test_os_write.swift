import Foundation

// Test OS file read and write
let osPath = "/Users/senioradvisor/clawd/emax-project/3. OS/Emax II rev 2.14.EMX"
let testPath = "/tmp/test_os_write.hda"

print("=== Testing OS file read/write ===")
print()

// Read OS file
let osData = try! Data(contentsOf: URL(fileURLWithPath: osPath))
print("OS file size: \(osData.count) bytes")
print()

// Create test image
FileManager.default.createFile(atPath: testPath, contents: nil)
let handle = try! FileHandle(forWritingTo: URL(fileURLWithPath: testPath))

// Truncate to 250MB (like real disk)
try! handle.truncate(atOffset: 250_398_720)
print("Created test image: 250,398,720 bytes")
print()

// Seek to cluster 1 (sector 98 = 0xC400 = 50,176)
let clusterStart = UInt64(98 * 512)
print("Seeking to cluster 1 offset: \(clusterStart) (0x\(String(clusterStart, radix: 16)))")
handle.seek(toFileOffset: clusterStart)

// Write OS data
print("Writing \(osData.count) bytes...")
handle.write(osData)
print("Write complete!")
print()

// Synchronize
handle.synchronizeFile()
handle.closeFile()

// Verify what was written
let verifyHandle = try! FileHandle(forReadingFrom: URL(fileURLWithPath: testPath))
verifyHandle.seek(toFileOffset: clusterStart)
let readBack = try! verifyHandle.read(upToCount: osData.count)!
verifyHandle.closeFile()

print("=== VERIFICATION ===")
print("Bytes written: \(osData.count)")
print("Bytes read back: \(readBack.count)")

if readBack.count == osData.count {
    print("✅ Size matches!")
    
    if readBack == osData {
        print("✅ Data matches byte-for-byte!")
    } else {
        print("❌ Data DIFFERS!")
        for i in 0..<min(osData.count, readBack.count) {
            if osData[i] != readBack[i] {
                print("  First diff at byte \(i): wrote 0x\(String(format: "%02X", osData[i])), read 0x\(String(format: "%02X", readBack[i]))")
                break
            }
        }
    }
} else {
    print("❌ Size mismatch!")
}

print()
print("Test file: \(testPath)")
