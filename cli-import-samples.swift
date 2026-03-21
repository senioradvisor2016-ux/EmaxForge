#!/usr/bin/env swift
// EmaxForge CLI - Import WAV Samples to HD image
// Simplified standalone version

import Foundation
import AVFoundation

print("📥 EmaxForge CLI - Sample Importer")
print("===================================\n")

// MARK: - Helpers

extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset]) |
        (UInt32(self[offset + 1]) << 8) |
        (UInt32(self[offset + 2]) << 16) |
        (UInt32(self[offset + 3]) << 24)
    }
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

// MARK: - WAV Loader

struct Sample {
    let name: String
    let pcmData: Data
    let sampleRate: Double
}

func loadWAV(url: URL) throws -> Sample {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let frameCount = AVAudioFrameCount(file.length)
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Buffer creation failed"])
    }
    
    try file.read(into: buffer)
    
    // Convert to mono 16-bit
    var pcmData = Data()
    let channelData = buffer.floatChannelData![0]
    
    for i in 0..<Int(buffer.frameLength) {
        let sample = Int16(max(-32768, min(32767, channelData[i] * 32767.0)))
        pcmData.append(Data([
            UInt8(UInt16(bitPattern: sample) & 0xFF),
            UInt8((UInt16(bitPattern: sample) >> 8) & 0xFF)
        ]))
    }
    
    let name = url.deletingPathExtension().lastPathComponent
        .prefix(12)
        .padding(toLength: 12, withPad: " ", startingAt: 0)
    
    return Sample(name: String(name), pcmData: pcmData, sampleRate: format.sampleRate)
}

// MARK: - EB2 Bank Builder

func buildEB2Bank(name: String, samples: [Sample]) -> Data {
    let paddedName = name.prefix(12).padding(toLength: 12, withPad: " ", startingAt: 0)
    var bank = Data(count: 0x1B8) // Header
    
    // Key pointer table (all point to start)
    for i in stride(from: 0, to: 0xCA, by: 2) {
        bank.writeU16LE(0x0200, at: i)
    }
    
    // Key output table (default)
    for i in stride(from: 0x100, to: 0x1A0, by: 4) {
        bank.writeU32LE(0, at: i)
    }
    
    // Metadata
    let totalSampleBytes = samples.reduce(0) { $0 + $1.pcmData.count }
    bank.writeU32LE(UInt32(totalSampleBytes + 0x200), at: 0x1A0) // Sample end
    bank.writeU32LE(UInt32(totalSampleBytes + 0x220), at: 0x1A4) // Preset end
    bank.writeU32LE(UInt32(samples.count * 32), at: 0x1A8) // Voice block size
    
    // Bank name
    if let nameData = paddedName.data(using: .ascii) {
        bank.replaceSubrange(0x1AC..<0x1B8, with: nameData.prefix(12))
    }
    
    // Preset header (single preset 'A')
    var preset = Data(count: 32)
    preset[0] = 0x41 // 'A' marker
    preset[3] = 99   // Volume
    preset[5] = 47   // Transpose center
    bank.append(preset)
    
    // Zone map 1 (42 bytes - one zone for all keys)
    bank.append(Data(repeating: 0x00, count: 42))
    
    // Padding
    bank.append(Data(count: 6))
    
    // Zone map 2 (48 bytes)
    bank.append(Data(repeating: 0x00, count: 48))
    
    // Zone pointers (4 bytes per zone)
    var sampleOffset: UInt32 = 0
    for sample in samples {
        bank.append(Data([
            UInt8(sampleOffset & 0xFF),
            UInt8((sampleOffset >> 8) & 0xFF),
            UInt8((sampleOffset >> 16) & 0xFF),
            0xFF
        ]))
        sampleOffset += UInt32(sample.pcmData.count)
    }
    
    // Voice parameters (32 bytes per zone)
    for _ in samples {
        var voice = Data(count: 32)
        voice[0] = 60  // Root key
        voice[1] = 0   // Low key
        voice[2] = 127 // High key
        voice[3] = 99  // Volume
        bank.append(voice)
    }
    
    // Sample data
    for sample in samples {
        bank.append(sample.pcmData)
    }
    
    return bank
}

// MARK: - Disk Image Writer

func importBankToImage(bankData: Data, bankName: String, imageURL: URL) throws {
    let handle = try FileHandle(forUpdating: imageURL)
    defer {
        // Ensure file doesn't grow beyond original size
        try? handle.truncate(atOffset: 250609664) // 239 MB
        try? handle.close()
    }
    
    // Read header
    handle.seek(toFileOffset: 0)
    let header = handle.readData(ofLength: 512)
    
    let clusterSize = Int(header.readU32LE(at: 4))
    let clusterAreaStart = UInt64(header.readU32LE(at: 0x20)) * 512
    
    // Read FAT
    handle.seek(toFileOffset: 0x400)
    let fatSize = 1024
    var fatData = handle.readData(ofLength: fatSize)
    var fat = [UInt16]()
    for i in stride(from: 0, to: fatSize, by: 2) {
        fat.append(fatData.readU16LE(at: i))
    }
    
    // Find free clusters
    let clustersNeeded = (bankData.count + clusterSize - 1) / clusterSize
    var freeClusters = [Int]()
    for i in 2..<512 {
        if fat[i] == 0 {
            freeClusters.append(i)
        }
        if freeClusters.count >= clustersNeeded { break }
    }
    
    guard freeClusters.count >= clustersNeeded else {
        throw NSError(domain: "EmaxForge", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Not enough space (need \(clustersNeeded), have \(freeClusters.count))"
        ])
    }
    
    let allocated = Array(freeClusters.prefix(clustersNeeded))
    
    // Write bank data to clusters
    for (i, cluster) in allocated.enumerated() {
        let dataStart = i * clusterSize
        let dataEnd = min(dataStart + clusterSize, bankData.count)
        let chunk = bankData[dataStart..<dataEnd]
        
        let offset = clusterAreaStart + UInt64(cluster) * UInt64(clusterSize)
        handle.seek(toFileOffset: offset)
        handle.write(chunk)
        
        // Pad
        if chunk.count < clusterSize {
            handle.write(Data(count: clusterSize - chunk.count))
        }
    }
    
    // Update FAT
    for i in 0..<allocated.count {
        let cluster = allocated[i]
        if i < allocated.count - 1 {
            fat[cluster] = UInt16(allocated[i + 1])
        } else {
            fat[cluster] = 0x7FFF // End of chain
        }
    }
    
    // Write FAT back
    for i in 0..<fat.count {
        fatData.writeU16LE(fat[i], at: i * 2)
    }
    handle.seek(toFileOffset: 0x400)
    handle.write(fatData)
    
    // Write Bank Name Table entry
    let bntStart = UInt64(header.readU32LE(at: 0x10)) * 512
    
    // Find free slot in BNT
    handle.seek(toFileOffset: bntStart)
    let bntData = handle.readData(ofLength: 90 * 32) // Max 90 banks
    
    var freeSlot: Int? = nil
    for i in 0..<90 {
        let offset = i * 32
        let firstByte = bntData[offset]
        if firstByte == 0 || firstByte == 0xFF {
            freeSlot = i
            break
        }
    }
    
    guard let slot = freeSlot else {
        throw NSError(domain: "EmaxForge", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "No free bank slots"
        ])
    }
    
    // Write BNT entry
    var bntEntry = Data(count: 32)
    let paddedName = bankName.prefix(16).padding(toLength: 16, withPad: " ", startingAt: 0)
    if let nameData = paddedName.data(using: .ascii) {
        bntEntry.replaceSubrange(0..<16, with: nameData.prefix(16))
    }
    bntEntry.writeU16LE(UInt16(allocated[0]), at: 24) // Start cluster
    bntEntry[26] = 0x81 // FLAGS
    
    handle.seek(toFileOffset: bntStart + UInt64(slot * 32))
    handle.write(bntEntry)
    
    print("✅ Imported '\(bankName)' (\(bankData.count) bytes, \(clustersNeeded) clusters)")
}

// MARK: - Main

let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
let samplesDir = desktop.appendingPathComponent("TestSamples")
let imageURL = desktop.appendingPathComponent("HD20.hda")

do {
    // Load WAV files
    let wavFiles = try FileManager.default.contentsOfDirectory(at: samplesDir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "wav" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    
    guard !wavFiles.isEmpty else {
        print("❌ No WAV files found in \(samplesDir.path)")
        exit(1)
    }
    
    print("📂 Found \(wavFiles.count) WAV files\n")
    
    // Load all samples
    var samples = [Sample]()
    for url in wavFiles {
        print("📄 Loading: \(url.lastPathComponent)")
        let sample = try loadWAV(url: url)
        samples.append(sample)
        print("   ✓ \(sample.pcmData.count) bytes, \(sample.sampleRate) Hz")
    }
    
    print("\n🔨 Building EB2 bank...")
    let bankData = buildEB2Bank(name: "Test Samples", samples: samples)
    print("   ✓ Bank size: \(bankData.count) bytes\n")
    
    print("💾 Importing to HD20.hda...")
    try importBankToImage(bankData: bankData, bankName: "Test Samples", imageURL: imageURL)
    
    print("\n🎉 Import complete!")
    print("   Bank: 'Test Samples'")
    print("   Samples: \(samples.count)")
    print("   Total size: \(bankData.count) bytes")
    
} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}
