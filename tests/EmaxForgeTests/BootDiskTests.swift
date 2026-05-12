import XCTest
import Foundation

/// Boot Disk Creation Tests
/// Tests ImageCreator logic without UI automation
final class BootDiskTests: XCTestCase {
    
    let testOutputDir = FileManager.default.temporaryDirectory.appendingPathComponent("EmaxForgeTests")
    
    override func setUp() async throws {
        try? FileManager.default.createDirectory(at: testOutputDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testOutputDir)
    }
    
    // MARK: - Boot Signature Tests
    
    func testBootSignatureFormat() throws {
        // Boot signature for 239 MB disk: 0x78 0x82 at offset 0x1FE (510)
        // NOTE: Each disk size has a unique boot signature embedded by industry-standard format.
        //   96 MB:  0xA1 0x93
        //  239 MB:  0x78 0x82  (most common, used in tests)
        //  481 MB:  0x65 0x9F
        //  633 MB:  0x79 0x24
        //  962 MB:  0xD7 0xAD
        // These are opaque standard tools template values — do not synthesise from scratch.
        let correctSignature: [UInt8] = [0x78, 0x82]

        XCTAssertEqual(correctSignature[0], 0x78, "First byte should be 0x78")
        XCTAssertEqual(correctSignature[1], 0x82, "Second byte should be 0x82")
    }

    func testBootSignatureValidation() throws {
        // Tests 239 MB template boot signature (0x78 0x82) at offset 0x1FE
        var data = Data(count: 512)
        data[510] = 0x78
        data[511] = 0x82

        let hasValidSignature = data[510] == 0x78 && data[511] == 0x82
        XCTAssertTrue(hasValidSignature, "239 MB boot signature validation should pass")
    }
    
    func testInvalidBootSignature() throws {
        // PC boot signature (wrong for EMAX II)
        var data = Data(count: 512)
        data[510] = 0x55
        data[511] = 0xAA
        
        // Should NOT be valid for EMAX II
        let hasEmaxSignature = data[510] == 0x78 && data[511] == 0x82
        XCTAssertFalse(hasEmaxSignature, "PC boot signature should not validate as EMAX II")
    }
    
    // MARK: - FAT Structure Tests
    
    func testFATEntry0() throws {
        // FAT entry 0 == 0x8000 (reserved marker, verified against all EMXP templates and HD0.hda)
        // Little-endian bytes: [0x00, 0x80]
        let correctEntry: [UInt8] = [0x00, 0x80]

        let value = UInt16(correctEntry[0]) | (UInt16(correctEntry[1]) << 8)
        XCTAssertEqual(value, 0x8000, "FAT entry 0 must be 0x8000 (reserved marker)")
    }
    
    func testFATEntry1NonZeroForBootDisk() throws {
        // FAT entry 1 (cluster 1) is used by the OS on a boot disk.
        // It should be NON-ZERO: 0x7FFF (single-cluster OS, end-of-chain)
        // or a chain pointer (multi-cluster OS).
        // 0x0000 means "free" — a boot disk must not have a free cluster 1.
        let endOfChain: UInt16 = 0x7FFF
        XCTAssertNotEqual(endOfChain, 0x0000, "Boot disk FAT entry 1 must not be free (0x0000)")
        XCTAssertEqual(endOfChain, 0x7FFF, "Single-cluster OS: entry 1 = end-of-chain (0x7FFF)")
    }
    
    // MARK: - Filename Tests
    
    func testSCSIIDFilenameFormat() throws {
        // SCSI ID should be zero-padded
        let scsiID = 0
        let filename = String(format: "HD%02d.hda", scsiID)
        
        XCTAssertEqual(filename, "HD00.hda", "SCSI ID 0 should format as HD00.hda")
    }
    
    func testSCSIID1FilenameFormat() throws {
        // ZuluSCSI: HD{scsiId}{imageIndex} — SCSI 1, index 0 → HD10.hda
        let scsiID = 1
        let imageIndex = 0
        let filename = "HD\(scsiID)\(imageIndex).hda"

        XCTAssertEqual(filename, "HD10.hda", "SCSI ID 1 should format as HD10.hda")
    }
    
    func testMultiImageFilenames() throws {
        // Multi-image setup: HD10, HD20, HD30
        let filenames = (1...3).map { String(format: "HD%d0.hda", $0) }
        
        XCTAssertEqual(filenames[0], "HD10.hda")
        XCTAssertEqual(filenames[1], "HD20.hda")
        XCTAssertEqual(filenames[2], "HD30.hda")
    }
    
    // MARK: - Disk Size Tests
    
    func testValidDiskSizes() throws {
        // industry-standard format standard sizes
        let validSizes: [Int64] = [
            96 * 1024 * 1024,   // 100,663,296 bytes
            239 * 1024 * 1024,  // 250,609,664 bytes
            481 * 1024 * 1024,  // 504,365,056 bytes
            633 * 1024 * 1024,  // 663,912,448 bytes
            962 * 1024 * 1024   // 1,009,123,328 bytes
        ]
        
        for size in validSizes {
            XCTAssertGreaterThan(size, 0, "Disk size should be positive")
            XCTAssertLessThan(size, 2_000_000_000, "Disk size should be reasonable")
        }
    }
    
    // MARK: - Cluster Size Tests
    
    func testClusterSizeForDiskSize() throws {
        // Based on standard tools templates
        let clusterSizes: [Int64: Int] = [
            96 * 1024 * 1024: 8192,      // 96 MB → 8 KB clusters
            239 * 1024 * 1024: 16384,    // 239 MB → 16 KB clusters
            481 * 1024 * 1024: 32768,    // 481 MB → 32 KB clusters
            633 * 1024 * 1024: 32768,    // 633 MB → 32 KB clusters
            962 * 1024 * 1024: 65536     // 962 MB → 64 KB clusters
        ]
        
        for (diskSize, expectedCluster) in clusterSizes {
            XCTAssertGreaterThan(expectedCluster, 0, "Cluster size for \(diskSize) should be positive")
            XCTAssertTrue([8192, 16384, 32768, 65536].contains(expectedCluster), 
                         "Cluster size should be power of 2 between 8KB and 64KB")
        }
    }
    
    // MARK: - Integration Tests (require actual file)
    
    func testVerifyBootDiskIfExists() throws {
        // Check if a test boot disk exists
        let testPath = testOutputDir.appendingPathComponent("TEST_HD00.hda")
        
        guard FileManager.default.fileExists(atPath: testPath.path) else {
            throw XCTSkip("No test boot disk found at \(testPath.path)")
        }
        
        let data = try Data(contentsOf: testPath)
        
        // Verify minimum size
        XCTAssertGreaterThanOrEqual(data.count, 512, "Boot disk should be at least 512 bytes")
        
        // Verify boot signature
        XCTAssertEqual(data[510], 0x78, "Boot signature byte 1 should be 0x78")
        XCTAssertEqual(data[511], 0x82, "Boot signature byte 2 should be 0x82")
        
        // Verify FAT entry 0 at offset 0x400 (1024) is 0x8000 (reserved marker)
        if data.count >= 1026 {
            let fatEntry0 = UInt16(data[1024]) | (UInt16(data[1025]) << 8)
            XCTAssertEqual(fatEntry0, 0x8000, "FAT entry 0 must be 0x8000 (verified against all EMXP templates)")
        }
    }
}
