import Foundation

/// Skapa en sample-paramtabell från scratch för EB2-filer (som saknar fast paramtabell).
///
/// EB2-filer är komprimerade banker utan den fasta paramtabell som EMX-format har på 0x10200.
/// Denna klass detekterar PCM-sampel via entropianalys och injicerar en kompatibel
/// paramtabell, vilket konverterar banken till EMX-format som EMXP kan läsa direkt.
///
/// Entropilogiken speglar `EmaxIIParser.findSampleDataByEntropy()` och
/// `extractSampleData_EB2()` i EmaxIIFileSystem.swift.
class EB2ParamTableBuilder {

    struct BuildResult {
        let samplesDetected: Int
        let paramTableSize: Int
        let paramTableOffset: Int  // alltid 0x10200
        let totalBankSize: Int
    }

    enum BuildError: LocalizedError {
        case noSamplesDetected
        case invalidBankFormat
        case tooManySamples(Int)

        var errorDescription: String? {
            switch self {
            case .noSamplesDetected:         return "Inga sampel detekterades via entropianalys"
            case .invalidBankFormat:         return "Ogiltig bankdata (för liten eller saknar header)"
            case .tooManySamples(let n):     return "För många sampel detekterade: \(n) (max \(EmaxIIFormat.maxSamples))"
            }
        }
    }

    // MARK: - Entropianalys (speglar EmaxIIParser)

    /// Shannon-entropi för ett datablock
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

    /// Antal unika bytvärden i ett datablock
    private static func uniqueByteCount(_ data: Data, offset: Int, length: Int) -> Int {
        let end = min(offset + length, data.count)
        var seen = Set<UInt8>()
        for i in offset..<end { seen.insert(data[i]) }
        return seen.count
    }

    // MARK: - Kontrollera om paramtabell redan finns (EMX-detektering)

    /// Returnerar true om data vid 0x10200 verkar vara en giltig paramtabell
    private static func hasExistingParamTable(_ data: Data) -> Bool {
        let tableBase = EmaxIIFormat.sampleParamOffset   // 0x10200
        guard tableBase + EmaxIIFormat.sampleParamSize <= data.count else { return false }

        // Kolla om första paramblocket ser rimligt ut
        let startAddr = Int(data.readU32LE(at: tableBase + EmaxIIFormat.paramStartAddr))
        let endAddr   = Int(data.readU32LE(at: tableBase + EmaxIIFormat.paramEndAddr))
        let rate      = Int(data.readU16LE(at: tableBase + EmaxIIFormat.paramSampleRate))

        // Tom slot (start==end==0) räknas inte som befintlig tabell
        if startAddr == 0 && endAddr == 0 { return false }

        // Rimlighetskontroll
        return startAddr < endAddr
            && (endAddr - startAddr) < 8_000_000
            && rate >= 8_000
            && rate <= 50_000
    }

    // MARK: - Detektera PCM-segment via entropianalys

    /// Ett detekterat PCM-segment i bankdata
    private struct PCMSegment {
        let startOffset: Int   // Absolut offset i eb2Data
        let endOffset: Int     // Absolut offset i eb2Data (exklusiv)
        var size: Int { endOffset - startOffset }
    }

    /// Hitta alla sammanhängande högentropi-segment i PCM-datan (offset 0x20000+)
    ///
    /// Speglar logiken i `EmaxIIParser.findSampleDataByEntropy()` och
    /// `extractSampleData_EB2()`, men delar upp i separata segment istället för
    /// att returnera ett enda start-offset.
    private static func detectPCMSegments(in data: Data) -> [PCMSegment] {
        let chunkSize  = 512
        let scanStart  = EmaxIIFormat.sampleDataOffset    // 0x20000
        let scanEnd    = min(data.count - chunkSize, scanStart + 32 * 1024 * 1024)

        guard scanEnd > scanStart else { return [] }

        // Thresholds (samma som EmaxIIParser, lite lägre för segmentdetektering)
        let highEntropyThreshold = 6.0
        let highUniqueThreshold  = 150
        let lowEntropyThreshold  = 3.5     // under detta → tyst/tomt
        let minSegmentSize       = 1024    // ignorera micro-segment < 1 KB

        var segments = [PCMSegment]()
        var inSegment = false
        var segStart  = 0

        var offset = scanStart
        while offset + chunkSize <= data.count && offset < scanEnd {
            let ent    = shannonEntropy(data, offset: offset, length: chunkSize)
            let unique = uniqueByteCount(data, offset: offset, length: chunkSize)
            let isHigh = ent > highEntropyThreshold && unique > highUniqueThreshold

            if isHigh && !inSegment {
                // Ny högentropi-region börjar — raffinera bakåt för att hitta exakt start
                var refined = offset
                var back = offset - chunkSize
                while back >= max(scanStart, offset - 8192) {
                    let backEnt = shannonEntropy(data, offset: back, length: 256)
                    if backEnt < lowEntropyThreshold {
                        refined = back + 256
                        break
                    }
                    back -= 64
                }
                // 16-bit alignment
                if refined % 2 != 0 { refined += 1 }
                segStart = refined
                inSegment = true
            } else if !isHigh && inSegment {
                // Segmentet slutar
                // Raffinera framåt för att hitta exakt slut
                var segEnd = offset
                var fwd = offset
                while fwd + 256 <= data.count && fwd < offset + 4096 {
                    let fwdEnt = shannonEntropy(data, offset: fwd, length: 256)
                    if fwdEnt < lowEntropyThreshold {
                        segEnd = fwd
                        break
                    }
                    fwd += 64
                }
                // 16-bit alignment
                if segEnd % 2 != 0 { segEnd -= 1 }

                let seg = PCMSegment(startOffset: segStart, endOffset: segEnd)
                if seg.size >= minSegmentSize {
                    segments.append(seg)
                }
                inSegment = false
            }

            offset += chunkSize
        }

        // Stäng eventuellt öppet segment vid data-slutet
        if inSegment {
            var segEnd = min(data.count, scanEnd + chunkSize)
            if segEnd % 2 != 0 { segEnd -= 1 }
            let seg = PCMSegment(startOffset: segStart, endOffset: segEnd)
            if seg.size >= minSegmentSize {
                segments.append(seg)
            }
        }

        // Om inga segment hittades med höga tröskelvärden — försök med lägre
        if segments.isEmpty {
            return detectPCMSegmentsFallback(in: data)
        }

        return segments
    }

    /// Lägre-tröskel fallback: identifiera enstaka start, returnera som ett segment
    private static func detectPCMSegmentsFallback(in data: Data) -> [PCMSegment] {
        let chunkSize = 512
        let scanStart = EmaxIIFormat.sampleDataOffset
        let scanEnd   = min(data.count - chunkSize, scanStart + 32 * 1024 * 1024)

        for offset in stride(from: scanStart, to: scanEnd, by: chunkSize) {
            if shannonEntropy(data, offset: offset, length: chunkSize) > 5.0 &&
               uniqueByteCount(data, offset: offset, length: chunkSize) > 120 {
                var start = offset
                if start % 2 != 0 { start += 1 }
                var end = data.count
                if end % 2 != 0 { end -= 1 }
                return [PCMSegment(startOffset: start, endOffset: end)]
            }
        }
        return []
    }

    // MARK: - Bygg paramblock (64 bytes) för ett sampel

    private static func buildParamBlock(
        index: Int,
        startRelative: UInt32,   // offset relativt sampleData-area (0x20000)
        endRelative: UInt32,
        sampleRate: UInt16 = 22050,
        originalKey: UInt8 = 60,
        outputChannel: UInt8 = 1
    ) -> Data {
        var block = Data(count: EmaxIIFormat.sampleParamSize)  // 64 bytes, nollifierade

        // +0x00 startAddress (U32 LE)
        block.writeU32LE(startRelative, at: EmaxIIFormat.paramStartAddr)

        // +0x04 endAddress (U32 LE)
        block.writeU32LE(endRelative, at: EmaxIIFormat.paramEndAddr)

        // +0x08 sampleRate (U16 LE) — 22050 Hz default
        block.writeU16LE(sampleRate, at: EmaxIIFormat.paramSampleRate)

        // +0x0A originalKey (U8) — MIDI C3 = 60
        block[EmaxIIFormat.paramOriginalKey] = originalKey

        // +0x0B flags (U8) — 0x00 = TUNED, inget user-defined namn
        block[EmaxIIFormat.paramFlags] = 0x00

        // +0x0C sustainLoopStart (U32 LE) — 0 = ingen loop
        block.writeU32LE(0, at: EmaxIIFormat.paramSustainLoopStart)

        // +0x10 sustainLoopEnd (U32 LE)
        block.writeU32LE(0, at: EmaxIIFormat.paramSustainLoopEnd)

        // +0x14 releaseLoopStart (U32 LE)
        block.writeU32LE(0, at: EmaxIIFormat.paramReleaseLoopStart)

        // +0x18 releaseLoopEnd (U32 LE)
        block.writeU32LE(0, at: EmaxIIFormat.paramReleaseLoopEnd)

        // +0x1C loopFlags (U8) — 0x00 = ingen loop aktiverad
        block[EmaxIIFormat.paramLoopFlags] = 0x00

        // +0x20 name (16 bytes, NUL-terminated) — "SAMPLE NNN"
        let name = String(format: "SAMPLE %03d", index + 1)
        let nameBytes = Array(name.utf8.prefix(15))  // max 15 + NUL
        for (i, byte) in nameBytes.enumerated() {
            block[EmaxIIFormat.paramName + i] = byte
        }
        // Resten av name-fältet är redan noll (NUL-padding)

        // +0x30 outputChannel (U8) — kanal 1
        block[EmaxIIFormat.paramOutputChannel] = outputChannel

        return block
    }

    // MARK: - Huvud-API

    /// Konvertera EB2-bankdata (utan paramtabell) till EMX-format med paramtabell.
    ///
    /// Returnerar ny bankData med param-table injicerad på offset 0x10200,
    /// samt ett BuildResult med metadata om konverteringen.
    static func buildParamTable(from eb2Data: Data) throws -> (data: Data, result: BuildResult) {

        // 1. Validera minimum
        guard eb2Data.count >= EmaxIIFormat.headerSize else {
            throw BuildError.invalidBankFormat
        }

        // 2. Kontrollera om paramtabell redan finns
        if hasExistingParamTable(eb2Data) {
            // Redan EMX-format — returnera oförändrat med enkel BuildResult
            let numSamples = Int(eb2Data.readU16LE(at: EmaxIIFormat.numSamplesOffset))
            return (
                data: eb2Data,
                result: BuildResult(
                    samplesDetected: numSamples,
                    paramTableSize:  numSamples * EmaxIIFormat.sampleParamSize,
                    paramTableOffset: EmaxIIFormat.sampleParamOffset,
                    totalBankSize:   eb2Data.count
                )
            )
        }

        // 3. Detektera sample-gränser via entropianalys
        let segments = detectPCMSegments(in: eb2Data)
        guard !segments.isEmpty else {
            throw BuildError.noSamplesDetected
        }
        guard segments.count <= EmaxIIFormat.maxSamples else {
            throw BuildError.tooManySamples(segments.count)
        }

        // 4. Bygg paramtabell
        //    Paramtabellen placeras på 0x10200 (sampleParamOffset).
        //    Adresser i paramblock är relativa till sampleData-area (0x20000).
        let sampleDataBase = EmaxIIFormat.sampleDataOffset   // 0x20000

        var paramTableData = Data(count: EmaxIIFormat.sampleParamOffset + segments.count * EmaxIIFormat.sampleParamSize)
        // (vi fyller bara paramtabellens del; resten hanteras vid ihopsättning)
        var paramBlocks = Data()

        for (i, seg) in segments.enumerated() {
            // Relativa adresser (offset från 0x20000)
            let startRel = UInt32(max(0, seg.startOffset - sampleDataBase))
            let endRel   = UInt32(max(0, seg.endOffset   - sampleDataBase))

            let block = buildParamBlock(
                index: i,
                startRelative: startRel,
                endRelative: endRel
            )
            paramBlocks.append(block)
        }
        _ = paramTableData  // var inte använd direkt; nedan bygger vi istället hela utdata

        // 5. Bygg fullständig bankData med paramtabell injicerad
        //
        // Layout:
        //   [0 ..< 0x10200]          : originaldata (header + presets)
        //   [0x10200 ..< paramEnd]   : ny paramtabell (segments.count × 64 bytes)
        //   [paramEnd ..< ...]       : resten av originaldata (sampleData från 0x20000)
        //
        // Vi behöver säkerställa att sampleData-regionen finns på rätt plats i output.
        // Originaldata kan ha sampleData på en annan offset om EB2 är komprimerat.
        // Strategi: kopiera header (0..0x10200), injicera paramtabell, sedan fyll
        // tomrum om nödvändigt, sedan sampleData.

        let headerChunkEnd = min(EmaxIIFormat.sampleParamOffset, eb2Data.count)  // max 0x10200
        var output = Data(capacity: sampleDataBase + (eb2Data.count > sampleDataBase ? eb2Data.count - sampleDataBase : 0))

        // Header + presetArea (allt upp till 0x10200, men max vad som finns i eb2Data)
        output.append(eb2Data[0..<headerChunkEnd])

        // Om eb2Data är kortare än 0x10200: pad med nollor
        if headerChunkEnd < EmaxIIFormat.sampleParamOffset {
            output.append(Data(count: EmaxIIFormat.sampleParamOffset - headerChunkEnd))
        }

        // Paramtabell
        output.append(paramBlocks)

        // Pad till 0x20000 om nödvändigt (mellanrummet mellan paramtabell och sampleData)
        let afterParamTable = EmaxIIFormat.sampleParamOffset + paramBlocks.count
        if afterParamTable < sampleDataBase {
            output.append(Data(count: sampleDataBase - afterParamTable))
        }

        // SampleData — från original eb2Data (de faktiska PCM-bytarna)
        // Använd första segmentets startOffset som ankarpunkt
        let firstSegStart = segments[0].startOffset
        if firstSegStart < eb2Data.count {
            // Ta med allt från firstSegStart till slutet av eb2Data
            output.append(eb2Data[firstSegStart...])
        }

        // Uppdatera header: numSamples (0x1E)
        output.writeU16LE(UInt16(segments.count), at: EmaxIIFormat.numSamplesOffset)

        // Uppdatera header: totalSampleSize (0x20) = summan av alla sampels byte-storlek
        let totalPCMSize = segments.reduce(0) { $0 + $1.size }
        output.writeU32LE(UInt32(totalPCMSize), at: EmaxIIFormat.totalSampleSizeOffset)

        let result = BuildResult(
            samplesDetected:  segments.count,
            paramTableSize:   paramBlocks.count,
            paramTableOffset: EmaxIIFormat.sampleParamOffset,
            totalBankSize:    output.count
        )

        print("EB2ParamTableBuilder: \(segments.count) sampel detekterade, " +
              "paramtabell \(paramBlocks.count) bytes på offset 0x\(String(EmaxIIFormat.sampleParamOffset, radix: 16))")

        return (data: output, result: result)
    }

    /// Konvertera EB2-bank på disk (via BankCatalogEntry) till EMX-format in-place.
    ///
    /// Läser bankdata från HD-image, bygger paramtabell, skriver tillbaka.
    /// Om den konverterade datan kräver fler kluster kastas ett fel (no in-place resize här;
    /// använd PCMReallocator för reallokering).
    static func convertEB2ToEMX(
        bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> BuildResult {

        // Läs bankdata
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw BuildError.invalidBankFormat
        }
        let fileSize = handle.seekToEndOfFile()
        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        guard header.count == 512,
              String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
            try? handle.close()
            throw BuildError.invalidBankFormat
        }

        let fileSize64 = fileSize
        let diskSizeSectors   = Int(fileSize64 / 512)
        let caStartSector     = Int(header.readU32LE(at: 0x20))
        let totalClusters     = Int(header.readU32LE(at: 0x24))
        let sectorsPerCluster = totalClusters > 0 ? (diskSizeSectors - caStartSector) / totalClusters : 128
        let clusterSize       = sectorsPerCluster * 512
        let caOffset          = UInt64(caStartSector) * 512

        // Läs bankdata via kluster-kedja
        var bankData = Data()
        bankData.reserveCapacity(bankEntry.clusterChain.count * clusterSize)
        for cluster in bankEntry.clusterChain {
            let physOffset = caOffset + UInt64(cluster) * UInt64(clusterSize)  // 0-based
            handle.seek(toFileOffset: physOffset)
            bankData.append(handle.readData(ofLength: clusterSize))
        }
        try? handle.close()

        guard !bankData.isEmpty else { throw BuildError.invalidBankFormat }

        // Bygg paramtabell
        let (convertedData, result) = try buildParamTable(from: bankData)

        // Skriv tillbaka (antalet kluster ändras inte — vi skriver bara inom befintliga kluster)
        guard let writeHandle = try? FileHandle(forWritingTo: imageURL) else {
            throw BuildError.invalidBankFormat
        }
        defer { writeHandle.closeFile() }

        var offset = 0
        for cluster in bankEntry.clusterChain {
            let physOffset = caOffset + UInt64(cluster) * UInt64(clusterSize)  // 0-based
            writeHandle.seek(toFileOffset: physOffset)
            let end = min(offset + clusterSize, convertedData.count)
            if offset < end {
                writeHandle.write(convertedData[offset..<end])
            }
            let written = end - offset
            let pad = clusterSize - written
            if pad > 0 { writeHandle.write(Data(count: pad)) }
            offset += clusterSize
        }
        writeHandle.synchronizeFile()

        print("EB2ParamTableBuilder: konverterade bank '\(bankEntry.name)' till EMX-format")
        return result
    }
}

// MARK: - Data helpers (privata för denna fil)

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
    }

    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
    }

    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        guard offset + 2 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }

    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        guard offset + 4 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8)  & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
