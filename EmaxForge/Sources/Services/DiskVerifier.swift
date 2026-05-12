import Foundation

/// Verifies EMAX II disk images against EMXP ground truth.
/// Call after every format, import, or create operation.
class DiskVerifier {
    
    struct VerifyResult {
        let passed: Bool
        let checks: [Check]
        let warnings: [String]
        
        var summary: String {
            let passCount = checks.filter(\.passed).count
            let failCount = checks.filter({ !$0.passed }).count
            let warnCount = warnings.count
            if failCount == 0 && warnCount == 0 {
                return "✅ All \(passCount) checks passed"
            } else if failCount == 0 {
                return "⚠️ \(passCount) passed, \(warnCount) warning(s)"
            } else {
                return "❌ \(failCount) FAILED, \(passCount) passed"
            }
        }
    }
    
    struct Check {
        let name: String
        let passed: Bool
        let detail: String
    }
    
    /// Full verification of a disk image
    static func verify(imageURL: URL) -> VerifyResult {
        var checks = [Check]()
        var warnings = [String]()
        
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            return VerifyResult(passed: false, checks: [Check(name: "File access", passed: false, detail: "Cannot open file")], warnings: [])
        }
        defer { handle.closeFile() }
        
        let fileSize = Int(handle.seekToEndOfFile())
        checks.append(Check(name: "File size", passed: fileSize >= 0x2000, detail: "\(fileSize) bytes (\(fileSize / 1024 / 1024) MB)"))
        guard fileSize >= 0x2000 else {
            return VerifyResult(passed: false, checks: checks, warnings: [])
        }
        
        // === Header ===
        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        
        let magic = String(data: header[0..<4], encoding: .ascii) ?? ""
        checks.append(Check(name: "EMX2 magic", passed: magic == "EMX2", detail: "'\(magic)'"))
        guard magic == "EMX2" else {
            return VerifyResult(passed: false, checks: checks, warnings: [])
        }
        
        let clusterSize = Int(header.readU32LE(at: 0x04))
        let headerField0x0C = Int(header.readU32LE(at: 0x0C))
        let bntStartSector = Int(header.readU32LE(at: 0x10))
        let maxBanks = Int(header.readU32LE(at: 0x14))
        let fatSectors = Int(header.readU32LE(at: 0x1C))
        let clusterAreaStart = Int(header.readU32LE(at: 0x20))
        let totalClusters = Int(header.readU32LE(at: 0x24))
        
        checks.append(Check(name: "Cluster size", passed: clusterSize > 0 && clusterSize < 10_000_000, detail: "\(clusterSize) bytes"))
        // FAT is ALWAYS at 0x400 (sector 2), but we note what header[0x0C] says
        checks.append(Check(name: "FAT location", passed: true, detail: "ALWAYS at 0x400 (header[0x0C]=\(headerField0x0C))"))
        checks.append(Check(name: "BNT start", passed: bntStartSector >= 2, detail: "sector \(bntStartSector) (0x\(String(bntStartSector * 512, radix: 16, uppercase: true)))"))
        checks.append(Check(name: "Max banks", passed: maxBanks > 0 && maxBanks <= 200, detail: "\(maxBanks)"))
        checks.append(Check(name: "Cluster area", passed: clusterAreaStart > bntStartSector, detail: "sector \(clusterAreaStart)"))
        checks.append(Check(name: "Total clusters", passed: totalClusters > 0 && totalClusters <= 2000, detail: "\(totalClusters)"))
        
        // === Layout order ===
        let layoutOK = bntStartSector >= 2 && bntStartSector < clusterAreaStart
        checks.append(Check(name: "Layout order", passed: layoutOK, detail: "FAT(0x400) < BNT(\(bntStartSector)) < Clusters(\(clusterAreaStart))"))
        
        // === FAT (ALWAYS at 0x400) ===
        let fatOffset = 0x400  // Hardcoded — verified against all EMXP templates
        let fatSize = fatSectors * 512
        let fatEntryCount = fatSize / 2
        
        guard fatOffset + fatSize <= fileSize else {
            checks.append(Check(name: "FAT bounds", passed: false, detail: "FAT extends beyond file"))
            return VerifyResult(passed: false, checks: checks, warnings: warnings)
        }
        
        handle.seek(toFileOffset: UInt64(fatOffset))
        let fatData = handle.readData(ofLength: fatSize)
        
        let fat0 = fatData.readU16LE(at: 0)
        checks.append(Check(name: "FAT[0] reserved", passed: fat0 == 0x8000, detail: "0x\(String(fat0, radix: 16, uppercase: true)) (expected 0x8000)"))
        
        // Count FAT usage
        var usedClusters = 0
        var freeClusters = 0
        var chainEnds = 0
        var invalidEntries = [Int]()
        
        for i in 1..<fatEntryCount {
            let val = fatData.readU16LE(at: i * 2)
            if val == 0x0000 {
                freeClusters += 1
            } else if val == 0x7FFF {
                usedClusters += 1
                chainEnds += 1
            } else if val == 0x8080 {
                // compat end-of-chain (old BankImporter format; treat as valid EOC)
                usedClusters += 1
                chainEnds += 1
            } else if val == 0x8000 {
                // reserved marker
            } else if val < UInt16(fatEntryCount) {
                usedClusters += 1
            } else {
                invalidEntries.append(i)
            }
        }
        
        checks.append(Check(name: "FAT entries", passed: invalidEntries.isEmpty, detail: "\(usedClusters) used, \(freeClusters) free, \(chainEnds) chains" + (invalidEntries.isEmpty ? "" : ", \(invalidEntries.count) INVALID")))
        
        if !invalidEntries.isEmpty {
            let first5 = invalidEntries.prefix(5).map { "[\($0)]=0x\(String(fatData.readU16LE(at: $0 * 2), radix: 16))" }
            warnings.append("Invalid FAT entries: \(first5.joined(separator: ", "))")
        }
        
        // === Validate FAT chains (no loops) ===
        var chainErrors = 0
        for i in 1..<fatEntryCount {
            let val = fatData.readU16LE(at: i * 2)
            if val != 0x0000 && val != 0x7FFF && val != 0x8080 && val != 0x8000 && val < UInt16(fatEntryCount) {
                // Follow chain, detect loops
                var visited = Set<Int>()
                var cur = Int(val)
                var steps = 0
                while cur < fatEntryCount && steps < fatEntryCount {
                    if visited.contains(cur) {
                        chainErrors += 1
                        break
                    }
                    visited.insert(cur)
                    let next = fatData.readU16LE(at: cur * 2)
                    if next == 0x7FFF || next == 0x8080 { break }
                    if next == 0x0000 { chainErrors += 1; break }
                    cur = Int(next)
                    steps += 1
                }
            }
        }
        checks.append(Check(name: "FAT chain integrity", passed: chainErrors == 0, detail: chainErrors == 0 ? "No loops or broken chains" : "\(chainErrors) chain error(s)"))
        
        // === BNT (Bank Name Table) ===
        let bntOffset = bntStartSector * 512
        let bntSize = (clusterAreaStart - bntStartSector) * 512
        
        guard bntOffset + bntSize <= fileSize else {
            checks.append(Check(name: "BNT bounds", passed: false, detail: "BNT extends beyond file"))
            return VerifyResult(passed: false, checks: checks, warnings: warnings)
        }
        
        handle.seek(toFileOffset: UInt64(bntOffset))
        let bntData = handle.readData(ofLength: bntSize)
        
        var bankCount = 0
        var osFound = false
        var duplicateNames = [String: Int]()
        var clusterConflicts = [Int: [Int]]()  // cluster -> [slot indices]
        
        let maxSlots = min(maxBanks + 1, bntSize / 32)
        for i in 0..<maxSlots {
            let entry = bntData.subdata(in: (i * 32)..<((i + 1) * 32))
            let isEmpty = entry.allSatisfy { $0 == 0x00 } || entry.allSatisfy { $0 == 0x42 }
            if isEmpty { continue }
            
            let name = String(data: entry[0..<16], encoding: .ascii)?.trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            // BNT field layout (verified empirically against HD0.hda, May 2026):
            //   [16-17]: startCluster (0x7800 = OS special marker, 0-based for user banks)
            //   [18-19]: clusterCount (stored hint; FAT chain is authoritative)
            let startCluster = Int(entry.readU16LE(at: 16))
            let flags = entry.readU16LE(at: 26)

            if i == 0 && name.contains("Software") {
                osFound = true
                // OS entry uses 0x7800 as startCluster special marker (not a real cluster)
                let isValidOSEntry = startCluster == 0x7800 || startCluster == 0x0000
                checks.append(Check(name: "OS entry", passed: isValidOSEntry, detail: "'\(name)' startCluster=0x\(String(startCluster, radix: 16)) flags=0x\(String(flags, radix: 16))"))
            } else {
                bankCount += 1
                duplicateNames[name, default: 0] += 1
                clusterConflicts[startCluster, default: []].append(i)

                // Bank cluster should be in FAT range and allocated
                if startCluster >= fatEntryCount {
                    warnings.append("Bank '\(name)' [slot \(i)] cluster \(startCluster) beyond FAT range (\(fatEntryCount))")
                } else {
                    let fatVal = fatData.readU16LE(at: startCluster * 2)
                    if fatVal == 0x0000 {
                        warnings.append("Bank '\(name)' [slot \(i)] cluster \(startCluster) not allocated in FAT")
                    }
                }
            }
        }
        
        checks.append(Check(name: "Bank count", passed: true, detail: "\(bankCount) banks loaded"))
        
        // Duplicate names
        let dupes = duplicateNames.filter { $0.value > 1 }
        if !dupes.isEmpty {
            let dupeList = dupes.map { "\($0.key) (×\($0.value))" }.joined(separator: ", ")
            warnings.append("Duplicate bank names: \(dupeList)")
        }
        
        // Cluster conflicts
        let conflicts = clusterConflicts.filter { $0.value.count > 1 }
        checks.append(Check(name: "No cluster conflicts", passed: conflicts.isEmpty, detail: conflicts.isEmpty ? "Each bank has unique cluster" : "\(conflicts.count) cluster(s) shared"))
        if !conflicts.isEmpty {
            for (cluster, slots) in conflicts {
                warnings.append("Cluster \(cluster) claimed by slots: \(slots)")
            }
        }
        
        // === Cluster area bounds ===
        let clusterAreaOffset = clusterAreaStart * 512
        let expectedEnd = clusterAreaOffset + totalClusters * clusterSize
        let boundsOK = expectedEnd <= fileSize + clusterSize  // Allow last partial cluster
        checks.append(Check(name: "Cluster area bounds", passed: boundsOK, detail: "Clusters end at 0x\(String(expectedEnd, radix: 16, uppercase: true)), file=0x\(String(fileSize, radix: 16, uppercase: true))"))
        
        // === OS data present (if OS entry exists) ===
        // OS is at cluster 1 (0-based): clusterAreaOffset + 1 * clusterSize (verified vs OSManager.swift)
        if osFound {
            let osDataOffset = UInt64(clusterAreaOffset) + UInt64(clusterSize)
            if osDataOffset + 16 <= UInt64(fileSize) {
                handle.seek(toFileOffset: osDataOffset)
                let osSnippet = handle.readData(ofLength: 16)
                let hasData = osSnippet.contains(where: { $0 != 0 })
                checks.append(Check(name: "OS data present", passed: hasData, detail: hasData ? "Non-zero at cluster 1 (0-based)" : "⚠️ Cluster 1 is all zeros — OS may not boot"))
            }
        }
        
        let allPassed = checks.allSatisfy(\.passed)
        return VerifyResult(passed: allPassed, checks: checks, warnings: warnings)
    }
    
    /// Quick verify — returns true/false + one-line summary
    static func quickVerify(imageURL: URL) -> (ok: Bool, summary: String) {
        let result = verify(imageURL: imageURL)
        return (result.passed, result.summary)
    }
    
    /// Print full report to console
    static func printReport(imageURL: URL) {
        let result = verify(imageURL: imageURL)
        let name = imageURL.lastPathComponent
        print("═══ Verify: \(name) ═══")
        for check in result.checks {
            let icon = check.passed ? "✅" : "❌"
            print("  \(icon) \(check.name): \(check.detail)")
        }
        for warning in result.warnings {
            print("  ⚠️  \(warning)")
        }
        print("  \(result.summary)")
        print()
    }
}

// MARK: - Data helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { buf in
            buf.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self)
        }
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buf in
            buf.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self)
        }
    }
}
