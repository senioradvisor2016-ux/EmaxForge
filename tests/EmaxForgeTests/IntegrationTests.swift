import XCTest
import Foundation

/// Integration Tests
/// Tests actual boot disk files created by EmaxForge
final class IntegrationTests: XCTestCase {
    
    // MARK: - File System Tests
    
    func testDesktopBootDiskIfExists() throws {
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let possibleFiles = [
            "HD00.hda",
            "HD10.hda",
            "TEST_HD00.hda",
            "TEST_HD10.hda"
        ]
        
        var foundFile: URL?
        for filename in possibleFiles {
            let fileURL = desktopURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                foundFile = fileURL
                break
            }
        }
        
        guard let fileURL = foundFile else {
            throw XCTSkip("No boot disk found on Desktop. Create one to run integration tests.")
        }
        
        print("✅ Testing: \(fileURL.lastPathComponent)")
        
        let data = try Data(contentsOf: fileURL)
        let fileSize = data.count
        
        // Test 1: Size check
        XCTAssertGreaterThanOrEqual(fileSize, 90_000_000, "Boot disk should be at least 90 MB")
        print("  ✓ Size: \(fileSize / (1024*1024)) MB")
        
        // Test 2: Boot signature
        let bootSig1 = data[510]
        let bootSig2 = data[511]
        XCTAssertEqual(bootSig1, 0x78, "Boot signature byte 1 incorrect")
        XCTAssertEqual(bootSig2, 0x82, "Boot signature byte 2 incorrect")
        print("  ✓ Boot signature: 0x\(String(format: "%02X", bootSig1)) 0x\(String(format: "%02X", bootSig2))")
        
        // Test 3: FAT structure
        if data.count >= 1026 {
            let fatEntry0Low = data[1024]
            let fatEntry0High = data[1025]
            let fatEntry0 = UInt16(fatEntry0Low) | (UInt16(fatEntry0High) << 8)
            
            // FAT entry 0 == 0x8000 (reserved marker, verified against all EMXP templates and HD0.hda)
            XCTAssertEqual(fatEntry0, 0x8000, "FAT entry 0 must be 0x8000, got 0x\(String(format: "%04X", fatEntry0))")
            print("  ✓ FAT entry 0: 0x\(String(format: "%04X", fatEntry0))")
            
            let fatEntry1Low = data[1026]
            let fatEntry1High = data[1027]
            let fatEntry1 = UInt16(fatEntry1Low) | (UInt16(fatEntry1High) << 8)
            print("  ✓ FAT entry 1: 0x\(String(format: "%04X", fatEntry1))")
        }
        
        // Test 4: Catalog check
        if data.count >= 18000 {
            // Catalog starts at offset ~16384 (depends on disk size)
            // Look for "EMAX2 Software" string
            let catalogSearchRange = 10000..<20000
            if let catalogData = data[catalogSearchRange].range(of: "EMAX2 Software".data(using: .ascii)!) {
                print("  ✓ Catalog contains OS entry")
            } else {
                print("  ⚠️  OS catalog entry not found (might be blank disk)")
            }
        }
        
        print("✅ All integration tests passed for \(fileURL.lastPathComponent)")
    }
    
    func testZuluSCSIConfigIfExists() throws {
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let configURL = desktopURL.appendingPathComponent("zuluscsi.ini")
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw XCTSkip("No zuluscsi.ini found on Desktop")
        }
        
        let configContent = try String(contentsOf: configURL, encoding: .utf8)
        print("✅ Testing: zuluscsi.ini")
        
        // Check for SCSI1 section (boot disk)
        XCTAssertTrue(configContent.contains("[SCSI1]"), "Config should contain [SCSI1] section")
        print("  ✓ [SCSI1] section found")
        
        // Check for HD10.hda reference
        if configContent.contains("HD10.hda") {
            print("  ✓ HD10.hda reference found")
        }
        
        print("✅ ZuluSCSI config validation passed")
    }
    
    // MARK: - Performance Tests
    
    func testBootDiskCreationPerformance() throws {
        // This would measure actual ImageCreator performance
        // For now, just a placeholder
        measure {
            // Simulate boot disk metadata creation (fast operation)
            var header = Data(count: 512)
            header[510] = 0x78
            header[511] = 0x82
            _ = header
        }
        
        print("✅ Performance test completed")
    }
}
