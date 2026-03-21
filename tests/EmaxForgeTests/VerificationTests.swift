import XCTest
@testable import EmaxForge

/// EMXP Gold Standard Verification
/// Exporterar alla banker från ref-diskar och jämför byte-för-byte mot EMXP
final class VerificationTests: XCTestCase {
    
    let goldStandardDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd/EmaxForge/verification/emxp-gold")
    let emaxforgeOutputDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd/EmaxForge/verification/emaxforge-output")
    let emaxII02Image = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd/emxp/Images/EmaxII-02.EZ2")
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: emaxforgeOutputDir, withIntermediateDirectories: true)
    }
    
    /// Test 1: Export alla banker från EmaxII-02
    func testExportAllBanks() throws {
        print("📦 Exporting all banks from EmaxII-02.EZ2...")
        let results = try BankExporter.exportAllBanks(from: emaxII02Image, to: emaxforgeOutputDir)
        
        print("✅ Exported \(results.count) banks")
        XCTAssertGreaterThan(results.count, 0, "Should export at least one bank")
        
        for result in results {
            print("  - \(result.bankName): \(result.sizeBytes) bytes, \(result.clustersUsed) clusters")
        }
    }
    
    /// Test 2: Jämför EmaxForge output mot EMXP gold standard
    func testCompareAgainstEMXPGold() throws {
        let emaxforgeFiles = try FileManager.default.contentsOfDirectory(at: emaxforgeOutputDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "EB2" }
        let goldFiles = try FileManager.default.contentsOfDirectory(at: goldStandardDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "EB2" }
        
        print("🔬 Comparing \(emaxforgeFiles.count) EmaxForge banks vs \(goldFiles.count) EMXP gold")
        
        var matches = 0
        var diffs = [(name: String, emaxforgeSize: Int, goldSize: Int)]()
        
        for emaxforgeFile in emaxforgeFiles {
            let name = emaxforgeFile.deletingPathExtension().lastPathComponent
            guard let goldFile = goldFiles.first(where: { $0.deletingPathExtension().lastPathComponent == name }) else {
                print("  ⚠️  No EMXP gold for '\(name)'")
                continue
            }
            
            let emaxforgeData = try Data(contentsOf: emaxforgeFile)
            let goldData = try Data(contentsOf: goldFile)
            
            if emaxforgeData == goldData {
                matches += 1
                print("  ✅ '\(name)' — EXACT match (\(emaxforgeData.count) bytes)")
            } else {
                diffs.append((name, emaxforgeData.count, goldData.count))
                print("  ❌ '\(name)' — DIFF (EmaxForge: \(emaxforgeData.count) bytes, EMXP: \(goldData.count) bytes)")
                
                // Byte-för-byte diff för första 256 bytes
                let maxLen = min(emaxforgeData.count, goldData.count, 256)
                for i in 0..<maxLen {
                    if emaxforgeData[i] != goldData[i] {
                        print("     Byte \(String(format: "0x%04X", i)): EmaxForge=\(String(format: "0x%02X", emaxforgeData[i])) EMXP=\(String(format: "0x%02X", goldData[i]))")
                    }
                }
            }
        }
        
        print("")
        print("📊 Results:")
        print("   Matches: \(matches)/\(emaxforgeFiles.count)")
        print("   Diffs:   \(diffs.count)")
        
        if !diffs.isEmpty {
            print("")
            print("❌ Differences found:")
            for diff in diffs {
                print("   - \(diff.name): EmaxForge=\(diff.emaxforgeSize) EMXP=\(diff.goldSize)")
            }
        }
        
        XCTAssertEqual(diffs.count, 0, "All banks should match EMXP gold standard byte-for-byte")
    }
}
