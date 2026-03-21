#!/usr/bin/env swift
import Foundation

print("🧪 Testing Wizard Flow (without UI)")
print("")

// Simulate wizard parameters
let destDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/EmaxForge/test-output")

let sizeMB = 239
let imageCount = 2
let includeOS = true
let osFileURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/emax-project/3. OS/Emax II FUNKAR.EMX")

print("Parameters:")
print("  Destination: \(destDir.path)")
print("  Size: \(sizeMB) MB")
print("  Images: \(imageCount)")
print("  Include OS: \(includeOS)")
print("  OS file: \(osFileURL.path)")
print("")

// Check OS exists
guard FileManager.default.fileExists(atPath: osFileURL.path) else {
    print("❌ OS file not found!")
    exit(1)
}

// Create directory
try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

for i in 0..<imageCount {
    let currentScsiID = i + 1  // HD1, HD2, HD3...
    let filename = "HD\(currentScsiID)0.hda"
    let destURL = destDir.appendingPathComponent(filename)
    
    print("[\(i+1)/\(imageCount)] Creating \(filename)...")
    
    if i == 0 && includeOS {
        print("  → Boot disk with OS")
        // This is where it might hang!
        print("  → Calling createBootableImage...")
        
        // Inline the key parts to see where it hangs
        let imageSize = 250398720
        print("  → Creating file...")
        FileManager.default.createFile(atPath: destURL.path, contents: nil)
        
        print("  → Opening file handle...")
        let handle = try FileHandle(forWritingTo: destURL)
        
        print("  → Truncating...")
        try handle.truncate(atOffset: UInt64(imageSize))
        
        print("  → Reading OS...")
        let osData = try Data(contentsOf: osFileURL)
        
        print("  → Writing header...")
        var header = Data(count: 512)
        header[0] = 0x45
        header[0x1FE] = 0x78
        header[0x1FF] = 0x82
        handle.seek(toFileOffset: 0)
        handle.write(header)
        
        print("  → Writing catalog...")
        let catalogOffset: UInt64 = 98 * 512
        handle.seek(toFileOffset: catalogOffset)
        var cat = Data(count: 32)
        handle.write(cat)
        
        print("  → Writing OS data...")
        let osOffset = catalogOffset + 4896
        handle.seek(toFileOffset: osOffset)
        handle.write(osData)
        
        print("  → Closing...")
        handle.closeFile()
        
        print("  ✅ Success")
    } else {
        print("  → Data disk (blank)")
        FileManager.default.createFile(atPath: destURL.path, contents: Data(count: 1024))
        print("  ✅ Success")
    }
}

print("")
print("🎉 All disks created!")
print("")
print("Results:")
let files = try FileManager.default.contentsOfDirectory(at: destDir, includingPropertiesForKeys: [.fileSizeKey])
for file in files.filter({ $0.pathExtension == "hda" }) {
    let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
    let size = attrs[.size] as! UInt64
    print("  \(file.lastPathComponent): \(size / 1024 / 1024) MB")
}
