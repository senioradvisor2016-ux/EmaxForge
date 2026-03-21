#!/usr/bin/env swift
// EmaxForge Test Setup Creator
// Creates fresh boot disk + test samples

import Foundation
import AVFoundation

print("🔨 EmaxForge Test Setup Creator")
print("================================\n")

// MARK: - Configuration

let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
let bootDiskPath = desktopURL.appendingPathComponent("HD10.hda")
let dataDiskPath = desktopURL.appendingPathComponent("HD20.hda")
let samplesDir = desktopURL.appendingPathComponent("TestSamples")

// MARK: - Step 1: Create Test Samples

print("📂 Step 1: Creating test samples...")

try? FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)

// Generate 10 test samples (sine waves at different frequencies)
let sampleRate: Double = 44100
let duration: Double = 2.0
let frequencies = [220.0, 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25, 587.33]
let noteNames = ["A3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5", "D5"]

for (index, freq) in frequencies.enumerated() {
    let filename = String(format: "%02d_%@_%.0fHz.wav", index + 1, noteNames[index], freq)
    let fileURL = samplesDir.appendingPathComponent(filename)
    
    // Generate sine wave
    let numSamples = Int(sampleRate * duration)
    var samples = [Int16]()
    
    for i in 0..<numSamples {
        let t = Double(i) / sampleRate
        let amplitude = sin(2.0 * .pi * freq * t)
        let sample = Int16(amplitude * 32767.0)
        samples.append(sample)
    }
    
    // Write WAV file
    let dataSize = samples.count * 2
    let fileSize = dataSize + 36
    
    var wavData = Data()
    
    // RIFF header
    wavData.append("RIFF".data(using: .ascii)!)
    wavData.append(Data([
        UInt8((fileSize >> 0) & 0xFF),
        UInt8((fileSize >> 8) & 0xFF),
        UInt8((fileSize >> 16) & 0xFF),
        UInt8((fileSize >> 24) & 0xFF)
    ]))
    wavData.append("WAVE".data(using: .ascii)!)
    
    // fmt chunk
    wavData.append("fmt ".data(using: .ascii)!)
    wavData.append(Data([16, 0, 0, 0])) // chunk size
    wavData.append(Data([1, 0])) // audio format (PCM)
    wavData.append(Data([1, 0])) // num channels (mono)
    
    // sample rate
    let sr = UInt32(sampleRate)
    wavData.append(Data([
        UInt8((sr >> 0) & 0xFF),
        UInt8((sr >> 8) & 0xFF),
        UInt8((sr >> 16) & 0xFF),
        UInt8((sr >> 24) & 0xFF)
    ]))
    
    // byte rate (SampleRate * NumChannels * BitsPerSample/8)
    let byteRate = UInt32(sampleRate * 2)
    wavData.append(Data([
        UInt8((byteRate >> 0) & 0xFF),
        UInt8((byteRate >> 8) & 0xFF),
        UInt8((byteRate >> 16) & 0xFF),
        UInt8((byteRate >> 24) & 0xFF)
    ]))
    
    wavData.append(Data([2, 0])) // block align
    wavData.append(Data([16, 0])) // bits per sample
    
    // data chunk
    wavData.append("data".data(using: .ascii)!)
    wavData.append(Data([
        UInt8((dataSize >> 0) & 0xFF),
        UInt8((dataSize >> 8) & 0xFF),
        UInt8((dataSize >> 16) & 0xFF),
        UInt8((dataSize >> 24) & 0xFF)
    ]))
    
    // sample data
    for sample in samples {
        wavData.append(Data([
            UInt8((UInt16(bitPattern: sample) >> 0) & 0xFF),
            UInt8((UInt16(bitPattern: sample) >> 8) & 0xFF)
        ]))
    }
    
    try wavData.write(to: fileURL)
    print("  ✅ Created: \(filename) (\(freq) Hz)")
}

print("\n✅ Created 10 test samples in ~/Desktop/TestSamples/\n")

// MARK: - Step 2: Instructions for EmaxForge

print("📋 Step 2: Create boot disks with EmaxForge")
print("============================================\n")

print("1️⃣  Open EmaxForge:")
print("   open ~/clawd/EmaxForge/.build/EmaxForge.app\n")

print("2️⃣  Create bootable HD10:")
print("   • Click 'Create Bootable Disk'")
print("   • Select disk size: 239 MB")
print("   • Output: HD10.hda")
print("   • Include OS: ✓\n")

print("3️⃣  Create data disk HD20:")
print("   • Click 'New Image'")
print("   • Disk size: 239 MB")
print("   • SCSI ID: 2")
print("   • Filename: HD20.hda\n")

print("4️⃣  Import test samples to HD20:")
print("   • Select HD20.hda")
print("   • Click 'Import Banks'")
print("   • Add folder: ~/Desktop/TestSamples/")
print("   • Convert WAV → EMAX II format\n")

print("5️⃣  Generate ZuluSCSI config:")
print("   • Tools menu → Generate ZuluSCSI Config")
print("   • Output: zuluscsi.ini\n")

print("✅ When done, SD card will have:")
print("   • HD10.hda (boot disk with OS)")
print("   • HD20.hda (data disk with 10 test samples)")
print("   • zuluscsi.ini (ZuluSCSI config)\n")

print("🚀 Ready for EMAX II testing!\n")

// MARK: - Alternative: CLI Test Script

print("💡 ALTERNATIVE: Run automated Swift test:")
print("   cd ~/clawd/EmaxForge/tests")
print("   swift test-boot-disk-validation.swift")
print("")
