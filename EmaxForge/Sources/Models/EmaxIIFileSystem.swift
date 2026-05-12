import Foundation

// MARK: - HD Image File System

/// Parsed EMAX II HD image (.hda / .EZ2)
struct EmaxIIFileSystem {
    let magic: String           // "EMX2"
    let clusterSize: Int
    let clusterAreaStartSector: UInt32  // Physical sector where cluster area begins (98-163, varies by disk size)
    let fat: [UInt16]           // entries = fatSectors * 256 (varies by disk size)
    let banks: [BankCatalogEntry]
    let imageSize: Int

    var maxClusters: Int { fat.count }
    /// Clusters in use = non-free, non-reserved entries in the FAT.
    /// Includes EOC markers (0x7FFF, 0x8080) since they occupy real cluster space.
    /// Excludes FAT[0] reserved marker (0x8000) and free entries (0x0000).
    var usedClusters: Int { fat.filter { $0 != 0x0000 && $0 != 0x8000 }.count }
    var freeClusters: Int { fat.filter { $0 == 0 }.count }
    /// OS entry uses startCluster=0x7800 as special marker (verified against EmaxII-02.ez2)
    var hasOS: Bool { banks.contains { $0.startCluster == 0x7800 } }
    var osName: String? { banks.first { $0.startCluster == 0x7800 }?.name }
    /// Banks excluding OS entry (OS uses startCluster=0x7800 marker)
    var userBanks: [BankCatalogEntry] { banks.filter { $0.startCluster != 0x7800 } }
    
    /// Physical byte offset where cluster area begins
    var clusterAreaStartOffset: UInt64 { UInt64(clusterAreaStartSector) * 512 }
}

/// A single entry in the bank catalog (32 bytes at offset 0x1000)
struct BankCatalogEntry: Identifiable, Hashable {
    let id = UUID()
    let catalogIndex: Int
    let name: String
    let bankIndex: UInt16
    let startCluster: UInt16
    let numPresets: UInt16
    let fieldA: UInt16
    let fieldB: UInt16
    let flags: UInt8
    let clusterChain: [Int]
    let sizeBytes: Int
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

// MARK: - EMAX II File Format Constants

/// File structure for EMAX II bank files:
/// ┌─────────────────────────────────────────────────┐
/// │ BANK HEADER (0x000-0x1FF) — 512 bytes           │
/// │ - Bank name, #presets, #samples, total size      │
/// ├─────────────────────────────────────────────────┤
/// │ PRESET AREA (0x200-0x101FF) — EMX full format    │
/// │ - 256 presets × 256 bytes = 64KB                 │
/// │ - Voice assignments, key areas per preset        │
/// ├─────────────────────────────────────────────────┤
/// │ SAMPLE PARAM AREA (0x10200-0x1FFFF)              │
/// │ - 999 samples × 64 bytes = ~63KB                │
/// │ - Start/end addr, rate, loop points, name        │
/// ├─────────────────────────────────────────────────┤
/// │ SAMPLE DATA (0x20000+ for EMX, variable for EB2) │
/// │ - Raw 16-bit PCM audio (little-endian)           │
/// └─────────────────────────────────────────────────┘
enum EmaxIIFormat {
    // Bank header
    static let headerSize = 0x200           // 512 bytes
    static let bankNameOffset = 0x04        // 16 chars
    static let numPresetsOffset = 0x1C      // UInt16 LE
    static let numSamplesOffset = 0x1E      // UInt16 LE
    static let totalSampleSizeOffset = 0x20 // UInt32 LE
    
    // Preset area (EMX full format — fixed layout)
    static let presetAreaOffset = 0x200
    static let presetSize = 0x100           // 256 bytes per preset
    static let maxPresets = 256
    
    // Sample parameter area (EMX full format — fixed layout)
    static let sampleParamOffset = 0x10200
    static let sampleParamSize = 0x40       // 64 bytes per sample param
    static let maxSamples = 999
    
    // Sample data (EMX full format — fixed offset)
    static let sampleDataOffset = 0x20000   // 128KB header total
    
    // Per-sample parameter field offsets (within each 64-byte block)
    // Layout (verified against EMXP v3.11.4 / Ghidra, offset within 64-byte param block):
    static let paramStartAddr          =  0   // +0x00 UInt32 LE — PCM start address
    static let paramEndAddr            =  4   // +0x04 UInt32 LE — PCM end address
    static let paramSampleRate         =  8   // +0x08 UInt16 LE — sample rate in Hz
    static let paramOriginalKey        = 10   // +0x0A UInt8   — original MIDI key (0–127)
    static let paramFlags              = 11   // +0x0B UInt8   — bit0=soundType, bit1=userDefinedName
    static let paramSustainLoopStart   = 12   // +0x0C UInt32 LE — sustain loop start
    static let paramSustainLoopEnd     = 16   // +0x10 UInt32 LE — sustain loop end
    static let paramReleaseLoopStart   = 20   // +0x14 UInt32 LE — release loop start
    static let paramReleaseLoopEnd     = 24   // +0x18 UInt32 LE — release loop end
    static let paramLoopFlags          = 28   // +0x1C UInt8   — loop mode flags
    static let paramName               = 32   // +0x20 16 chars — sample name (ASCII, NUL-padded)
    static let paramOutputChannel      = 48   // +0x30 UInt8   — output channel (1-based)

    // Legacy aliases kept for existing callsites
    static let paramLoopStart          = paramSustainLoopStart
    static let paramLoopEnd            = paramSustainLoopEnd
    
    // Audio specs (NS32CG16 — little-endian CPU)
    static let defaultSampleRate = 39063    // ~39.0625 kHz (crystal divider)
    static let bitDepth = 16
    // Available rates: ADC always records at 39.0625kHz, DSP downconverts
    static let sampleRates: [Double] = [20000, 22050, 27778, 31250, 39063, 44100]
}

// MARK: - EB2 Bank Structure

/// Parsed bank data (from HD image cluster chain or standalone .EB2 file)
struct EmaxIIBankData {
    let bankName: String
    let numPresets: Int
    let numSamples: Int
    let totalSampleSize: Int
    let sampleDataSize: Int
    let sampleParameters: [SampleParameter]
    
    // Legacy fields from first preset (for backwards compatibility)
    let presetType: PresetType
    let numZones: Int
    let presetHeader: PresetHeader?
    
    enum PresetType: CustomStringConvertible {
        case singleA
        case multi
        case unknown(UInt8)
        
        var description: String {
            switch self {
            case .singleA: return "Single (A)"
            case .multi: return "Multi"
            case .unknown(let v): return String(format: "Unknown (0x%02X)", v)
            }
        }
    }
    
    struct PresetHeader {
        let volume: UInt8
        let transpose: UInt8
        let tuneCoarse: UInt8
        let tuneFine: UInt8
    }
}

/// Individual sample parameter from the sample parameter area
struct SampleParameter: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
    let startAddress: Int       // Byte offset (relative for EB2, absolute for EMX)
    let endAddress: Int
    let sampleRate: Int
    let loopStart: Int
    let loopEnd: Int
    let hasLoop: Bool
    let originalKey: Int        // MIDI note
    
    var sizeInBytes: Int { max(0, endAddress - startAddress) }
    var sizeInFrames: Int { sizeInBytes / 2 }  // 16-bit = 2 bytes per frame
    var isValid: Bool { startAddress < endAddress && sizeInBytes > 0 && sizeInBytes < 8_000_000 }
    
    var duration: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(sizeInFrames) / Double(sampleRate)
    }
}

// MARK: - Sample Extraction Result

/// Extracted sample data from a bank, ready for playback
struct BankSampleData {
    let samples: [SampleEntry]
    let rawPCM: Data            // All sample data concatenated
    let sampleDataOffset: Int   // Where sample data starts in the bank
    
    struct SampleEntry: Identifiable {
        let id = UUID()
        let index: Int
        let name: String
        let pcmData: Data
        let sampleRate: Int
        let loopStart: Int?
        let loopEnd: Int?
        let rootKey: Int
        
        var frameCount: Int { pcmData.count / 2 }
        var duration: Double {
            guard sampleRate > 0 else { return 0 }
            return Double(frameCount) / Double(sampleRate)
        }
    }
    
    /// Total duration using first sample's rate as reference
    var duration: Double {
        samples.reduce(0) { $0 + $1.duration }
    }
    
    /// Convenience: get combined PCM of all samples
    var estimatedSampleRate: Double {
        Double(samples.first?.sampleRate ?? EmaxIIFormat.defaultSampleRate)
    }
}

// MARK: - Parser

enum EmaxIIParser {
    
    enum ParseError: LocalizedError {
        case invalidMagic
        case fileTooSmall
        case readError
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .invalidMagic: return "Not a valid EMAX II image (missing EMX2 magic)"
            case .fileTooSmall: return "File too small to be a valid image"
            case .readError: return "Could not read file"
            case .cancelled: return "Parsing was cancelled"
            }
        }
    }
    
    // MARK: HD Image parsing
    
    /// Async version with cancellation support
    static func parseHDImageAsync(at url: URL) async throws -> EmaxIIFileSystem {
        try await withTaskCancellationHandler {
            try await Task {
                try parseHDImage(at: url)
            }.value
        } onCancel: {
            // Nothing to cancel in sync version, but we check Task.isCancelled in loop
        }
    }
    
    static func parseHDImage(at url: URL) throws -> EmaxIIFileSystem {
        let fileSize = Int((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0)
        guard fileSize >= 0x2000 else { throw ParseError.fileTooSmall }
        
        // Read ONLY the metadata we need (~17KB) using pread-style approach
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw ParseError.readError
        }
        defer { try? handle.close() }
        
        // Read header (512 bytes at offset 0)
        try? handle.seek(toOffset: 0)
        guard let header = try? handle.read(upToCount: 512), header.count == 512 else {
            throw ParseError.readError
        }
        
        let magic = String(data: header[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else { throw ParseError.invalidMagic }
        
        // Cluster size from header[0x04]. Do NOT require % 512 == 0 — the EMAX II format
        // stores opaque byte-count values that may not be sector-aligned (e.g. 96 MB → 196352,
        // % 512 = 256; 962 MB → 1969408, % 512 = 256). Use if non-zero and ≤ 4 MB.
        let rawCS = Int(header.readU32LE(at: 4))
        let clusterSize = rawCS > 0 && rawCS <= 4_194_304 ? rawCS : 0
        guard clusterSize > 0 else { throw ParseError.readError }

        let bntStartSector = header.readU32LE(at: 0x10)
        let maxBanks = Int(header.readU32LE(at: 0x14))
        let fatSectors = Int(header.readU32LE(at: 0x1C))
        let clusterAreaStartSector = header.readU32LE(at: 0x20)

        // Read FAT (ALWAYS at 0x400, size from header)
        let fatSize = fatSectors * 512
        guard fatSize > 0 else { throw ParseError.readError }
        try? handle.seek(toOffset: 0x400)
        guard let fatData = try? handle.read(upToCount: fatSize), fatData.count == fatSize else {
            throw ParseError.readError
        }
        
        var fat = [UInt16]()
        fat.reserveCapacity(fatSize / 2)
        for i in stride(from: 0, to: fatSize, by: 2) {
            fat.append(fatData.readU16LE(at: i))
        }
        
        // Read BNT/catalog (offset from header[0x10], NOT hardcoded 0x1000)
        let bntOffset = UInt64(bntStartSector) * 512
        let bntSize = (Int(clusterAreaStartSector) - Int(bntStartSector)) * 512
        guard bntSize > 0 else { throw ParseError.readError }
        try? handle.seek(toOffset: bntOffset)
        guard let catalogData = try? handle.read(upToCount: bntSize) else {
            throw ParseError.readError
        }
        
        var banks = [BankCatalogEntry]()
        
        // Parse catalog entries from the read data
        let maxSlots = min(maxBanks + 1, bntSize / 32)
        for i in 0..<maxSlots {
            // Check for cancellation every 10 entries
            if i % 10 == 0, Task.isCancelled {
                throw ParseError.cancelled
            }
            
            let offset = i * 32
            guard offset + 32 <= catalogData.count else { break }
            let entry = Data(catalogData[offset..<(offset + 32)])
            guard entry.count == 32 else { break }
            
            let nameBytes = Data(entry[0..<16])
            // Skip empty slots (continue, not break — there may be gaps)
            if nameBytes.allSatisfy({ $0 == 0 }) { continue }
            
            // Skip invalid entries (0xFF-filled = deleted/empty slot)
            if nameBytes.allSatisfy({ $0 == 0xFF }) { continue }
            
            let name = String(data: nameBytes, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            guard !name.isEmpty else { break }
            
            // BNT entry layout verified against EmaxII-02.ez2 reference disk:
            //   +00..+0F  name (16 bytes)
            //   +10..+11  startCluster
            //   +12..+13  clusterCount
            //   +14..+15  numPresets
            //   +16..+17  f22 (unknown)
            //   +18..+19  idx (preset address, 0x0200 per slot)
            //   +1A..+1B  flags = 0x0081
            //   +1C..+1F  zeros
            let startClusterRaw = entry.readU16LE(at: 16)
            // OS entry uses 0x7800 as startCluster marker — allow it; skip 0xFFFF invalid
            if startClusterRaw == 0xFFFF { continue }
            
            let bankIndex = entry.readU16LE(at: 24)   // idx = preset address
            let startCluster = entry.readU16LE(at: 16)
            let numPresets = entry.readU16LE(at: 20)
            let fieldA = entry.readU16LE(at: 22)
            let fieldB = entry.readU16LE(at: 18)       // clusterCount
            let flags = entry[26]
            
            let chain = traceChain(fat: fat, start: Int(startCluster))
            
            banks.append(BankCatalogEntry(
                catalogIndex: i,
                name: name,
                bankIndex: bankIndex,
                startCluster: startCluster,
                numPresets: numPresets,
                fieldA: fieldA,
                fieldB: fieldB,
                flags: flags,
                clusterChain: chain,
                sizeBytes: chain.count * clusterSize
            ))
        }
        
        return EmaxIIFileSystem(
            magic: magic,
            clusterSize: clusterSize,
            clusterAreaStartSector: clusterAreaStartSector,
            fat: fat,
            banks: banks,
            imageSize: fileSize
        )
    }
    
    // MARK: Format detection
    
    /// EMAX II bank data comes in two formats:
    /// - **EMX** (full RAM image, .EM2, HD image banks): Fixed offsets, sample param table at 0x10200
    /// - **EB2** (compressed bank file, .EB2): Variable layout, no param table
    enum BankFormat {
        case emx    // Full RAM image — fixed offsets, param table available
        case eb2    // Compressed bank — variable offsets, needs entropy scan
    }
    
    /// Detect whether bank data is in EMX or EB2 format
    static func detectBankFormat(_ data: Data) -> BankFormat {
        // EMX format has valid sample params at 0x10200
        // and valid header fields at 0x1C/0x1E
        guard data.count > EmaxIIFormat.sampleParamOffset + EmaxIIFormat.sampleParamSize else {
            return .eb2  // Too small for EMX
        }
        
        // Check header: numPresets and numSamples should be reasonable
        let numPresets = Int(data.readU16LE(at: EmaxIIFormat.numPresetsOffset))
        let numSamples = Int(data.readU16LE(at: EmaxIIFormat.numSamplesOffset))
        
        if numPresets > EmaxIIFormat.maxPresets || numSamples > EmaxIIFormat.maxSamples {
            return .eb2  // Invalid counts → not EMX
        }
        
        // Spot-check a few sample params at 0x10200 for sanity
        var validParams = 0
        for i in 0..<min(max(numSamples, 5), 20) {
            let base = EmaxIIFormat.sampleParamOffset + (i * EmaxIIFormat.sampleParamSize)
            guard base + EmaxIIFormat.sampleParamSize <= data.count else { break }
            
            let startAddr = Int(data.readU32LE(at: base))
            let endAddr = Int(data.readU32LE(at: base + 4))
            let rate = Int(data.readU16LE(at: base + 8))
            
            if startAddr == 0 && endAddr == 0 { continue } // Empty slot, OK
            if startAddr < endAddr && (endAddr - startAddr) < 8_000_000 && rate >= 8000 && rate <= 50000 {
                validParams += 1
            }
        }
        
        return validParams > 0 ? .emx : .eb2
    }
    
    // MARK: Bank data parsing
    
    static func parseBankData(_ data: Data) -> EmaxIIBankData? {
        guard data.count >= 0x200 else { return nil }
        
        let format = detectBankFormat(data)
        
        switch format {
        case .emx:
            return parseBankData_EMX(data)
        case .eb2:
            return parseBankData_EB2(data)
        }
    }
    
    /// Parse EMX format (full RAM image) — fixed offsets, param table at 0x10200
    private static func parseBankData_EMX(_ data: Data) -> EmaxIIBankData? {
        let bankName = extractString(from: data, offset: EmaxIIFormat.bankNameOffset, length: 16)
        let numPresets = min(Int(data.readU16LE(at: EmaxIIFormat.numPresetsOffset)), EmaxIIFormat.maxPresets)
        let numSamples = min(Int(data.readU16LE(at: EmaxIIFormat.numSamplesOffset)), EmaxIIFormat.maxSamples)
        let totalSampleSize = Int(data.readU32LE(at: EmaxIIFormat.totalSampleSizeOffset))
        
        // Parse sample parameter table at 0x10200
        let sampleParams = parseSampleParameters_EMX(from: data, expectedCount: numSamples)
        
        // Sample data at 0x20000
        let sampleDataSize = data.count > EmaxIIFormat.sampleDataOffset
            ? data.count - EmaxIIFormat.sampleDataOffset : 0
        
        // First preset info (at 0x200)
        let (presetType, presetHeader, numZones) = parseFirstPreset(data, presetBase: EmaxIIFormat.presetAreaOffset)
        
        return EmaxIIBankData(
            bankName: bankName, numPresets: numPresets, numSamples: numSamples,
            totalSampleSize: totalSampleSize, sampleDataSize: sampleDataSize,
            sampleParameters: sampleParams,
            presetType: presetType, numZones: numZones, presetHeader: presetHeader
        )
    }
    
    /// Parse EB2 format (compressed bank file) — original offsets
    private static func parseBankData_EB2(_ data: Data) -> EmaxIIBankData? {
        guard data.count >= 0x1C0 else { return nil }
        
        // EB2 bank name at 0x1AC (12 bytes)
        let bankName = String(data: data[0x1AC..<min(0x1B8, data.count)], encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
        
        // EB2 doesn't have reliable preset/sample counts in header
        // Count zones from zone map at 0x1F8-0x227
        let (presetType, presetHeader, numZones) = parseFirstPreset(data, presetBase: 0x1B8)
        
        // Sample data size via entropy scan
        let sampleDataSize: Int
        if let sampleStart = findSampleDataByEntropy(in: data) {
            sampleDataSize = data.count - sampleStart
        } else {
            sampleDataSize = 0
        }
        
        return EmaxIIBankData(
            bankName: bankName, numPresets: 0, numSamples: 0,
            totalSampleSize: sampleDataSize, sampleDataSize: sampleDataSize,
            sampleParameters: [],  // No param table in EB2
            presetType: presetType, numZones: numZones, presetHeader: presetHeader
        )
    }
    
    /// Parse first preset info for display
    private static func parseFirstPreset(_ data: Data, presetBase: Int) -> (
        EmaxIIBankData.PresetType, EmaxIIBankData.PresetHeader?, Int
    ) {
        guard data.count > presetBase + 0x28 else {
            return (.unknown(0), nil, 0)
        }
        
        let marker = data[0x1B8]
        let presetType: EmaxIIBankData.PresetType
        var presetHeader: EmaxIIBankData.PresetHeader?
        
        switch marker {
        case 0x41:
            presetType = .singleA
            if data.count > 0x1BF {
                presetHeader = EmaxIIBankData.PresetHeader(
                    volume: data[0x1BB], transpose: data[0x1BD],
                    tuneCoarse: data[0x1BE], tuneFine: data[0x1BF]
                )
            }
        case 0x01: presetType = .multi
        default: presetType = .unknown(marker)
        }
        
        var numZones = 0
        if data.count >= 0x228 {
            var maxZone: Int = -1
            for i in 0x1F8..<0x228 {
                let z = Int(data[i])
                if z != 0xFF && z > maxZone { maxZone = z }
            }
            numZones = maxZone + 1
        }
        
        return (presetType, presetHeader, numZones)
    }
    
    // MARK: Parse sample parameter table (EMX format only)
    
    /// Read sample parameters from 0x10200 (EMX full format only).
    /// Each parameter is 64 bytes: start/end addresses, rate, loop, name.
    private static func parseSampleParameters_EMX(from data: Data, expectedCount: Int) -> [SampleParameter] {
        var params = [SampleParameter]()
        let paramOffset = EmaxIIFormat.sampleParamOffset
        let paramSize = EmaxIIFormat.sampleParamSize
        let maxToScan = min(expectedCount > 0 ? expectedCount : 100, EmaxIIFormat.maxSamples)
        
        guard paramOffset + paramSize <= data.count else { return [] }
        
        for i in 0..<maxToScan {
            let base = paramOffset + (i * paramSize)
            guard base + paramSize <= data.count else { break }
            
            let startAddr = Int(data.readU32LE(at: base + EmaxIIFormat.paramStartAddr))
            let endAddr = Int(data.readU32LE(at: base + EmaxIIFormat.paramEndAddr))
            
            if startAddr == 0 && endAddr == 0 { continue }
            guard startAddr < endAddr && (endAddr - startAddr) < 8_000_000 else { continue }
            
            var sampleRate = Int(data.readU16LE(at: base + EmaxIIFormat.paramSampleRate))
            if sampleRate < 8000 || sampleRate > 50000 { sampleRate = EmaxIIFormat.defaultSampleRate }
            
            let loopStart = Int(data.readU32LE(at: base + EmaxIIFormat.paramLoopStart))
            let loopEnd = Int(data.readU32LE(at: base + EmaxIIFormat.paramLoopEnd))
            
            let name = extractString(from: data, offset: base + EmaxIIFormat.paramName, length: 16)
            
            params.append(SampleParameter(
                index: i, name: name.isEmpty ? "Sample \(i + 1)" : name,
                startAddress: startAddr, endAddress: endAddr,
                sampleRate: sampleRate,
                loopStart: loopStart, loopEnd: loopEnd,
                hasLoop: loopEnd > loopStart && loopEnd > 0,
                originalKey: 60 + (i % 12)
            ))
        }
        
        return params
    }
    
    /// Extract ASCII string from data
    private static func extractString(from data: Data, offset: Int, length: Int) -> String {
        guard offset >= 0 && offset + length <= data.count else { return "" }
        var chars = [Character]()
        for i in 0..<length {
            let byte = data[offset + i]
            if byte == 0 { break }
            if byte >= 32 && byte < 127 { chars.append(Character(UnicodeScalar(byte))) }
        }
        return String(chars).trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: Read bank data from HD image
    
    static func readBankData(from url: URL, entry: BankCatalogEntry, clusterSize: Int, clusterAreaStartSector: UInt32) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        
        let clusterAreaStart = UInt64(clusterAreaStartSector) * 512
        
        var data = Data()
        for cluster in entry.clusterChain {
            // 0-based cluster addressing: cluster n → caOffset + n × clusterSize
            // cluster 0 = reserved (FAT[0]=0x8000); cluster 1 = OS; cluster 2+ = banks.
            // Verified against HD0.hda (May 2026) and EmaxIIFileSystem.swift.
            let physicalOffset = clusterAreaStart + UInt64(cluster) * UInt64(clusterSize)
            handle.seek(toFileOffset: physicalOffset)
            data.append(handle.readData(ofLength: clusterSize))
        }
        return data
    }
    
    // MARK: Sample extraction
    
    /// Extract sample PCM data from bank data.
    ///
    /// For EMX format: uses sample parameter table at 0x10200 for exact boundaries.
    /// For EB2 format: uses entropy scanning, returns single "Full Bank" entry.
    static func extractSampleData(from bankData: Data) -> BankSampleData? {
        guard bankData.count >= EmaxIIFormat.headerSize else { return nil }
        
        let format = detectBankFormat(bankData)
        
        switch format {
        case .emx:
            return extractSampleData_EMX(from: bankData)
        case .eb2:
            return extractSampleData_EB2(from: bankData)
        }
    }
    
    /// EMX format: use sample param table for precise per-sample extraction
    private static func extractSampleData_EMX(from data: Data) -> BankSampleData? {
        let numSamples = Int(data.readU16LE(at: EmaxIIFormat.numSamplesOffset))
        let params = parseSampleParameters_EMX(from: data, expectedCount: numSamples)
        
        let sampleDataStart = EmaxIIFormat.sampleDataOffset  // 0x20000
        guard sampleDataStart < data.count else { return nil }
        
        let rawPCM = Data(data[sampleDataStart...])
        var entries = [BankSampleData.SampleEntry]()
        
        for param in params where param.isValid {
            // In EMX format, addresses are relative to sample data area
            let start = param.startAddress
            let end = param.endAddress
            
            guard start >= 0, end > start, end <= rawPCM.count else { continue }
            
            let alignedEnd = end - (end % 2 != 0 ? 1 : 0)
            guard alignedEnd > start else { continue }
            
            entries.append(BankSampleData.SampleEntry(
                index: param.index, name: param.name,
                pcmData: Data(rawPCM[start..<alignedEnd]),
                sampleRate: param.sampleRate,
                loopStart: param.hasLoop ? param.loopStart : nil,
                loopEnd: param.hasLoop ? param.loopEnd : nil,
                rootKey: param.originalKey
            ))
        }
        
        if entries.isEmpty {
            // Fallback: single entry with all PCM data
            entries.append(BankSampleData.SampleEntry(
                index: 0, name: "Full Bank", pcmData: rawPCM,
                sampleRate: EmaxIIFormat.defaultSampleRate,
                loopStart: nil, loopEnd: nil, rootKey: 60
            ))
        }
        
        return BankSampleData(samples: entries, rawPCM: rawPCM, sampleDataOffset: sampleDataStart)
    }
    
    /// EB2 format: use entropy scanning, split by zones if available
    private static func extractSampleData_EB2(from data: Data) -> BankSampleData? {
        guard let sampleStart = findSampleDataByEntropy(in: data) else { return nil }
        
        let rawPCM = Data(data[sampleStart...])
        guard rawPCM.count >= 4 else { return nil }
        
        // Count zones for splitting
        var maxZone: Int = -1
        if data.count >= 0x228 {
            for i in 0x1F8..<0x228 {
                let z = Int(data[i])
                if z != 0xFF && z > maxZone { maxZone = z }
            }
        }
        let numZones = max(maxZone + 1, 1)
        
        var entries = [BankSampleData.SampleEntry]()
        
        if numZones == 1 {
            entries.append(BankSampleData.SampleEntry(
                index: 0, name: "Full Bank", pcmData: rawPCM,
                sampleRate: EmaxIIFormat.defaultSampleRate,
                loopStart: nil, loopEnd: nil, rootKey: 60
            ))
        } else {
            // Split equally by zones (heuristic for EB2 without param table)
            let bytesPerZone = rawPCM.count / numZones
            for z in 0..<numZones {
                let offset = z * bytesPerZone
                let length = (z == numZones - 1) ? (rawPCM.count - offset) : bytesPerZone
                guard offset + length <= rawPCM.count else { continue }
                entries.append(BankSampleData.SampleEntry(
                    index: z, name: "Zone \(z + 1)",
                    pcmData: Data(rawPCM[offset..<(offset + length)]),
                    sampleRate: EmaxIIFormat.defaultSampleRate,
                    loopStart: nil, loopEnd: nil, rootKey: 60 + z
                ))
            }
        }
        
        return BankSampleData(samples: entries, rawPCM: rawPCM, sampleDataOffset: sampleStart)
    }
    
    /// Entropy-based fallback for compressed EB2 files where the parameter
    /// table isn't at the standard offset.
    private static func findSampleDataByEntropy(in data: Data) -> Int? {
        let chunkSize = 512
        let scanStart = 0x1000
        let scanEnd = min(data.count - chunkSize, 0x30000)
        guard scanEnd > scanStart else { return nil }
        
        // Find first high-entropy chunk (PCM audio)
        for offset in stride(from: scanStart, to: scanEnd, by: chunkSize) {
            let entropy = shannonEntropy(data, offset: offset, length: chunkSize)
            let unique = uniqueByteCount(data, offset: offset, length: chunkSize)
            
            if entropy > 7.0 && unique > 180 {
                // Refine backwards
                var refined = offset
                for back in stride(from: offset, to: max(offset - 8192, scanStart), by: -64) {
                    if shannonEntropy(data, offset: back, length: 256) < 5.5 {
                        refined = back + 64
                        break
                    }
                }
                // Align to 16-bit
                if refined % 2 != 0 { refined += 1 }
                return refined
            }
        }
        
        // Lower threshold fallback
        for offset in stride(from: scanStart, to: scanEnd, by: chunkSize) {
            if shannonEntropy(data, offset: offset, length: chunkSize) > 6.0 &&
               uniqueByteCount(data, offset: offset, length: chunkSize) > 150 {
                return offset
            }
        }
        
        return nil
    }
    
    /// Shannon entropy for a data region
    private static func shannonEntropy(_ data: Data, offset: Int, length: Int) -> Double {
        let end = min(offset + length, data.count)
        let len = end - offset
        guard len > 0 else { return 0 }
        var freq = [UInt8: Int]()
        for i in offset..<end { freq[data[i], default: 0] += 1 }
        var entropy: Double = 0
        for (_, count) in freq {
            let p = Double(count) / Double(len)
            entropy -= p * log2(p)
        }
        return entropy
    }
    
    /// Count unique bytes in a region
    private static func uniqueByteCount(_ data: Data, offset: Int, length: Int) -> Int {
        let end = min(offset + length, data.count)
        var seen = Set<UInt8>()
        for i in offset..<end { seen.insert(data[i]) }
        return seen.count
    }
    
    // MARK: FAT chain tracing
    
    private static func traceChain(fat: [UInt16], start: Int) -> [Int] {
        var chain = [start]
        var current = start
        var seen = Set([current])
        
        while current < fat.count {
            let next = Int(fat[current])
            if next == 0x7FFF || next == 0x8080 || next == 0 { break }  // 0x8080 = compat EOC
            if seen.contains(next) { break }
            seen.insert(next)
            chain.append(next)
            current = next
        }
        return chain
    }
}

// MARK: - Data helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { buf in
            let base = buf.baseAddress!.advanced(by: offset)
            return base.loadUnaligned(as: UInt16.self)
        }
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buf in
            let base = buf.baseAddress!.advanced(by: offset)
            return base.loadUnaligned(as: UInt32.self)
        }
    }
}
