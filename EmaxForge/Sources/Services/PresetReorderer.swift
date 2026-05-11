import Foundation

/// Reorder presets within an EMAX II bank (swap or move by rotating the preset area).
///
/// Preset area layout (EMX full format — Ghidra-verified):
///   Starts at offset 0x200 in bank data.
///   Each preset occupies exactly 0x100 (256) bytes.
///   Max 256 presets (indices 0–255).
///   Empty slots have a NUL/space-only 12-byte name at +0x00.
///
/// All operations are purely in-band: only the 256-byte preset blocks are moved.
/// Sample param entries and PCM data remain untouched.
class PresetReorderer {

    // MARK: - Public types

    struct ReorderResult {
        let swappedPresets: [(Int, Int)]  // pairs of indices that changed position
    }

    enum ReorderError: LocalizedError {
        case indexOutOfRange(Int)
        case sameIndex
        case bankReadError(String)
        case bankWriteError(String)

        var errorDescription: String? {
            switch self {
            case .indexOutOfRange(let i):
                return "Preset index \(i) is out of range (0–255)"
            case .sameIndex:
                return "Source and destination indices are the same"
            case .bankReadError(let msg):
                return "Bank read error: \(msg)"
            case .bankWriteError(let msg):
                return "Bank write error: \(msg)"
            }
        }
    }

    // MARK: - Constants

    private static let presetAreaOffset = 0x200
    private static let presetSize       = 0x100
    private static let maxPresets       = 256

    // MARK: - Swap two presets

    /// Atomically swap two preset blocks in a bank.
    ///
    /// Reads both 256-byte preset blocks, writes them back in swapped positions.
    /// The rest of the bank (sample params, PCM) is not modified.
    static func swapPresets(
        indexA: Int,
        indexB: Int,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> ReorderResult {
        guard (0..<maxPresets).contains(indexA) else { throw ReorderError.indexOutOfRange(indexA) }
        guard (0..<maxPresets).contains(indexB) else { throw ReorderError.indexOutOfRange(indexB) }
        guard indexA != indexB else { throw ReorderError.sameIndex }

        let geo = try loadGeometry(from: imageURL)
        var bankData = try readBank(entry: bankEntry, imageURL: imageURL, geo: geo)

        let offsetA = Self.presetAreaOffset + indexA * Self.presetSize
        let offsetB = Self.presetAreaOffset + indexB * Self.presetSize

        guard offsetA + Self.presetSize <= bankData.count,
              offsetB + Self.presetSize <= bankData.count else {
            throw ReorderError.bankReadError("Bank data too small for preset indices \(indexA)/\(indexB)")
        }

        // Extract both blocks
        let blockA = bankData[offsetA ..< offsetA + Self.presetSize]
        let blockB = bankData[offsetB ..< offsetB + Self.presetSize]

        // Write B into A's position, A into B's position
        bankData.replaceSubrange(offsetA ..< offsetA + Self.presetSize, with: blockB)
        bankData.replaceSubrange(offsetB ..< offsetB + Self.presetSize, with: blockA)

        try writeBank(bankData, entry: bankEntry, imageURL: imageURL, geo: geo)

        return ReorderResult(swappedPresets: [(indexA, indexB)])
    }

    // MARK: - Move preset (rotation)

    /// Move a preset from `sourceIndex` to `destinationIndex`, rotating intervening presets.
    ///
    /// If destination > source, presets in [source+1 .. destination] shift left by one
    /// (i.e., towards lower indices), and the source preset lands at destinationIndex.
    ///
    /// If destination < source, presets in [destination .. source-1] shift right by one
    /// (i.e., towards higher indices), and the source preset lands at destinationIndex.
    ///
    /// Example (move index 2 → 5):
    ///   Before: [A][B][C][D][E][F]
    ///   After:  [A][B][D][E][F][C]
    ///
    /// Example (move index 5 → 2):
    ///   Before: [A][B][C][D][E][F]
    ///   After:  [A][B][F][C][D][E]
    static func movePreset(
        from sourceIndex: Int,
        to destinationIndex: Int,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> ReorderResult {
        guard (0..<maxPresets).contains(sourceIndex) else {
            throw ReorderError.indexOutOfRange(sourceIndex)
        }
        guard (0..<maxPresets).contains(destinationIndex) else {
            throw ReorderError.indexOutOfRange(destinationIndex)
        }
        guard sourceIndex != destinationIndex else { throw ReorderError.sameIndex }

        let geo = try loadGeometry(from: imageURL)
        var bankData = try readBank(entry: bankEntry, imageURL: imageURL, geo: geo)

        let lo  = min(sourceIndex, destinationIndex)
        let hi  = max(sourceIndex, destinationIndex)
        let rangeBytes = (hi - lo + 1) * Self.presetSize
        let areaBase   = Self.presetAreaOffset + lo * Self.presetSize

        guard areaBase + rangeBytes <= bankData.count else {
            throw ReorderError.bankReadError("Bank data too small for move range \(lo)–\(hi)")
        }

        // Extract the affected range into a mutable buffer
        var slice = Data(bankData[areaBase ..< areaBase + rangeBytes])
        let count = hi - lo + 1  // number of preset blocks in the slice

        // In the slice, sourceIndex is at local position (sourceIndex - lo)
        let localSrc = sourceIndex - lo   // 0-based within slice
        let localDst = destinationIndex - lo

        // Extract the source block
        let srcOff   = localSrc * Self.presetSize
        let sourceBlock = slice[srcOff ..< srcOff + Self.presetSize]

        if destinationIndex > sourceIndex {
            // Shift [localSrc+1 .. localDst] one step left (each moves down by one slot)
            for i in localSrc ..< localDst {
                let fromOff = (i + 1) * Self.presetSize
                let toOff   = i       * Self.presetSize
                slice.replaceSubrange(
                    toOff ..< toOff + Self.presetSize,
                    with: slice[fromOff ..< fromOff + Self.presetSize]
                )
            }
        } else {
            // Shift [localDst .. localSrc-1] one step right (each moves up by one slot)
            for i in stride(from: localSrc - 1, through: localDst, by: -1) {
                let fromOff = i       * Self.presetSize
                let toOff   = (i + 1) * Self.presetSize
                slice.replaceSubrange(
                    toOff ..< toOff + Self.presetSize,
                    with: slice[fromOff ..< fromOff + Self.presetSize]
                )
            }
        }

        // Place the source block at destination
        let dstOff = localDst * Self.presetSize
        slice.replaceSubrange(dstOff ..< dstOff + Self.presetSize, with: sourceBlock)

        // Write the modified slice back into bankData
        bankData.replaceSubrange(areaBase ..< areaBase + rangeBytes, with: slice)

        try writeBank(bankData, entry: bankEntry, imageURL: imageURL, geo: geo)

        // Report all positions that changed
        var changed = [(Int, Int)]()
        if destinationIndex > sourceIndex {
            for i in sourceIndex...destinationIndex {
                let newPos = i == destinationIndex ? sourceIndex : i + 1
                if newPos != i { changed.append((i, newPos)) }
            }
        } else {
            for i in destinationIndex...sourceIndex {
                let newPos = i == destinationIndex ? sourceIndex : i - 1
                if newPos != i { changed.append((i, newPos)) }
            }
        }

        return ReorderResult(swappedPresets: changed)
    }

    // MARK: - Private helpers

    private static func loadGeometry(from imageURL: URL) throws -> BankDataWriter.DiskGeometry {
        do {
            return try BankDataWriter.loadGeometry(from: imageURL)
        } catch {
            throw ReorderError.bankReadError(error.localizedDescription)
        }
    }

    private static func readBank(
        entry: BankCatalogEntry,
        imageURL: URL,
        geo: BankDataWriter.DiskGeometry
    ) throws -> Data {
        do {
            return try BankDataWriter.readBankData(entry: entry, from: imageURL, geometry: geo)
        } catch {
            throw ReorderError.bankReadError(error.localizedDescription)
        }
    }

    private static func writeBank(
        _ data: Data,
        entry: BankCatalogEntry,
        imageURL: URL,
        geo: BankDataWriter.DiskGeometry
    ) throws {
        do {
            try BankDataWriter.writeBankData(data, entry: entry, to: imageURL, geometry: geo)
        } catch {
            throw ReorderError.bankWriteError(error.localizedDescription)
        }
    }
}
