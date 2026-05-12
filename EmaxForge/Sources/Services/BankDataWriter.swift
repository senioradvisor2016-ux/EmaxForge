import Foundation

/// Base infrastructure for reading and writing bank data buffers to/from EMAX II HD images.
///
/// Disk layout (verified against working disk, all offsets Ghidra-verified):
///   Header:  sector 0 (0x000), 512 bytes
///   FAT:     ALWAYS at 0x400 (sector 2), size = header[0x1C] sectors
///   BNT:     sector header[0x10]*512, 32-byte entries, max header[0x14] banks
///   Clusters: sector header[0x20]*512, clusterSize read from header[0x04] (fallback: computed)
///
/// Cluster offset formula: ca_off + cluster * clusterSize  (0-based, verified vs EmaxIIFileSystem.swift)
///
/// Bank data buffer layout (EMX full format):
///   0x000–0x1FF  Bank header (512 bytes)
///   0x200–0x101FF  Preset area: 256 presets × 256 bytes each
///   0x10200–0x1FFFF  Sample param area: up to 999 samples × 64 bytes each
///   0x20000+     Sample PCM data
enum BankDataWriter {

    // MARK: - Error types

    enum BankDataError: LocalizedError {
        case notEmaxImage
        case imageTooSmall
        case cannotOpenImage(String)
        case dataTooLarge(needed: Int, available: Int)
        case invalidClusterChain
        case writeError(String)

        var errorDescription: String? {
            switch self {
            case .notEmaxImage:
                return "Not a valid EMAX II image (missing EMX2 magic)"
            case .imageTooSmall:
                return "Image file too small to contain a valid EMAX II header"
            case .cannotOpenImage(let path):
                return "Cannot open disk image for writing: \(path)"
            case .dataTooLarge(let needed, let available):
                return "Data too large: need \(needed) bytes but cluster chain holds only \(available) bytes"
            case .invalidClusterChain:
                return "Bank catalog entry has an empty or invalid cluster chain"
            case .writeError(let msg):
                return "Write error: \(msg)"
            }
        }
    }

    // MARK: - Disk geometry

    /// Parsed EMAX II disk geometry extracted from the 512-byte header at offset 0.
    ///
    /// All field offsets verified empirically against HD0.hda and EMXP reference images (May 2026).
    struct DiskGeometry {
        /// Bytes per cluster (computed, not stored directly in header — see note below)
        let clusterSize: Int
        /// Number of 512-byte sectors occupied by the FAT
        let fatSectors: UInt32
        /// Sector number where the BNT (Bank Name Table) starts
        let bntStartSector: UInt32
        /// Maximum number of user banks (from header[0x14])
        let maxBanks: Int
        /// Sector number where the cluster area starts
        let clusterAreaStartSector: UInt32
        /// Total number of clusters on disk
        let totalClusters: Int

        /// FAT is ALWAYS at byte offset 0x400 regardless of header field 0x0C
        var fatOffset: UInt64 { 0x400 }
        /// Size of FAT in bytes
        var fatSize: Int { Int(fatSectors) * 512 }
        /// Total number of 16-bit FAT entries
        var fatEntryCount: Int { fatSize / 2 }
        /// Byte offset of the BNT area
        var bntOffset: UInt64 { UInt64(bntStartSector) * 512 }
        /// Byte offset of the cluster data area
        var clusterAreaOffset: UInt64 { UInt64(clusterAreaStartSector) * 512 }

        /// Byte offset for a given cluster number (0-based).
        ///
        /// Verified against HD0.hda (original EMAX II hardware):
        ///   cluster 0 → clusterAreaOffset (STEEL DRUMS / first bank)
        ///   cluster 1 → clusterAreaOffset + 1×clusterSize
        func clusterOffset(_ cluster: Int) -> UInt64 {
            clusterAreaOffset + UInt64(cluster) * UInt64(clusterSize)
        }
    }

    // MARK: - Geometry loading

    /// Parse and return the disk geometry from the header of an EMAX II image.
    ///
    /// Note on clusterSize: header[0x04] holds clusterSize on original EMAX II hardware disks
    /// (e.g. HD0.hda). If that value is a valid multiple of 512, it is used directly.
    /// Otherwise cluster size is computed from geometry (for EMXP-created disks).
    ///
    /// - Parameter imageURL: URL of the .hda / .EZ2 disk image
    /// - Returns: Parsed DiskGeometry
    static func loadGeometry(from imageURL: URL) throws -> DiskGeometry {
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw BankDataError.cannotOpenImage(imageURL.path)
        }
        defer { handle.closeFile() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            throw BankDataError.imageTooSmall
        }
        guard fileSize >= 0x2000 else { throw BankDataError.imageTooSmall }

        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        guard header.count == 512 else { throw BankDataError.imageTooSmall }

        // BNT +0x00..+0x03 magic "EMX2"
        guard String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
            throw BankDataError.notEmaxImage
        }

        let caStartSector = Int(header.readU32LE(at: 0x20))  // header +0x20: cluster area sector
        let totalClusters = Int(header.readU32LE(at: 0x24))  // header +0x24: total clusters

        // Prefer clusterSize from header[0x04] (original EMAX II hardware format: HD0.hda).
        // Fall back to geometry-based computation for EMXP-created disks.
        let headerClusterSize = Int(header.readU32LE(at: 0x04))
        let clusterSize: Int
        if headerClusterSize > 0 && headerClusterSize % 512 == 0 && headerClusterSize <= 4_194_304 {
            clusterSize = headerClusterSize
        } else {
            let diskSizeSectors   = Int(fileSize / 512)
            let sectorsPerCluster = totalClusters > 0
                ? (diskSizeSectors - caStartSector) / totalClusters
                : 128
            clusterSize = sectorsPerCluster * 512
        }

        return DiskGeometry(
            clusterSize:            clusterSize,
            fatSectors:             header.readU32LE(at: 0x1C), // header +0x1C: FAT size in sectors
            bntStartSector:         header.readU32LE(at: 0x10), // header +0x10: BNT start sector
            maxBanks:               Int(header.readU32LE(at: 0x14)), // header +0x14: max bank slots
            clusterAreaStartSector: header.readU32LE(at: 0x20), // header +0x20: cluster area sector
            totalClusters:          totalClusters
        )
    }

    // MARK: - Read bank data

    /// Read the entire bank data buffer for a catalog entry by following its cluster chain.
    ///
    /// Reads each cluster in `entry.clusterChain` sequentially and concatenates the raw bytes.
    /// The returned Data is exactly `chain.count * clusterSize` bytes.
    ///
    /// - Parameters:
    ///   - entry:    BankCatalogEntry with a populated `clusterChain`
    ///   - imageURL: URL of the EMAX II disk image
    ///   - geometry: Disk geometry (from `loadGeometry`)
    /// - Returns: Raw bank data buffer
    static func readBankData(
        entry: BankCatalogEntry,
        from imageURL: URL,
        geometry: DiskGeometry
    ) throws -> Data {
        guard !entry.clusterChain.isEmpty else {
            throw BankDataError.invalidClusterChain
        }

        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw BankDataError.cannotOpenImage(imageURL.path)
        }
        defer { handle.closeFile() }

        var bankData = Data()
        bankData.reserveCapacity(entry.clusterChain.count * geometry.clusterSize)

        for cluster in entry.clusterChain {
            // 0-based cluster offset: ca_off + cluster * clusterSize (via geo.clusterOffset)
            let offset = geometry.clusterOffset(cluster)
            handle.seek(toFileOffset: offset)
            let chunk = handle.readData(ofLength: geometry.clusterSize)
            bankData.append(chunk)
        }

        return bankData
    }

    // MARK: - Write bank data

    /// Write a modified bank data buffer back to the exact clusters of a catalog entry.
    ///
    /// The buffer must not be larger than the space available in the cluster chain.
    /// If `data.count` is smaller than the total cluster capacity, the remaining
    /// bytes in the last cluster are zero-padded.
    ///
    /// - Parameters:
    ///   - data:     The modified bank buffer to write
    ///   - entry:    BankCatalogEntry with a populated `clusterChain`
    ///   - imageURL: URL of the EMAX II disk image (opened for updating)
    ///   - geometry: Disk geometry (from `loadGeometry`)
    /// - Throws: `BankDataError.dataTooLarge` if data exceeds available cluster space;
    ///           `BankDataError.invalidClusterChain` if the chain is empty
    static func writeBankData(
        _ data: Data,
        entry: BankCatalogEntry,
        to imageURL: URL,
        geometry: DiskGeometry
    ) throws {
        guard !entry.clusterChain.isEmpty else {
            throw BankDataError.invalidClusterChain
        }

        let availableBytes = entry.clusterChain.count * geometry.clusterSize
        guard data.count <= availableBytes else {
            throw BankDataError.dataTooLarge(needed: data.count, available: availableBytes)
        }

        guard let handle = try? FileHandle(forUpdating: imageURL) else {
            throw BankDataError.cannotOpenImage(imageURL.path)
        }
        defer {
            handle.synchronizeFile()
            handle.closeFile()
        }

        var dataOffset = 0

        for cluster in entry.clusterChain {
            // 0-based cluster offset: ca_off + cluster * clusterSize (via geo.clusterOffset)
            let physicalOffset = geometry.clusterOffset(cluster)
            handle.seek(toFileOffset: physicalOffset)

            let chunkStart = dataOffset
            let chunkEnd   = min(dataOffset + geometry.clusterSize, data.count)

            if chunkStart < chunkEnd {
                // Write valid data bytes
                handle.write(data[chunkStart..<chunkEnd])

                let writtenInChunk = chunkEnd - chunkStart
                let remaining = geometry.clusterSize - writtenInChunk
                if remaining > 0 {
                    // Zero-pad the tail of the last cluster
                    handle.write(Data(count: remaining))
                }
            } else {
                // Data exhausted — zero-fill remaining clusters entirely
                handle.write(Data(count: geometry.clusterSize))
            }

            dataOffset += geometry.clusterSize
        }
    }
}

// MARK: - Data helpers

private extension Data {
    func readU8(at offset: Int) -> UInt8 {
        guard offset < count else { return 0 }
        return self[offset]
    }

    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
    }

    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
    }
}
