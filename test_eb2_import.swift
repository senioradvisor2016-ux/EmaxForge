#!/usr/bin/env swift
import Foundation

// Load EB2Reader
let eb2Path = "/Users/senioradvisor/clawd/standard/EMAX2SF2/Alan Wilder - Depeche Mode [Emax II]/SOMEBODY.EB2"
let eb2URL = URL(fileURLWithPath: eb2Path)

print("🔍 Testing .EB2 reader...")
print("File: \(eb2URL.lastPathComponent)")

do {
    // Read EB2
    let data = try Data(contentsOf: eb2URL)
    print("✅ File size: \(data.count) bytes (\(Double(data.count) / 1024 / 1024) MB)")
    
    // Parse header
    var nameBytes = [UInt8](repeating: 0, count: 16)
    data.copyBytes(to: &nameBytes, from: 0..<16)
    
    if let name = String(bytes: nameBytes, encoding: .ascii)?
        .trimmingCharacters(in: .controlCharacters)
        .trimmingCharacters(in: .whitespaces) {
        print("✅ Bank name: '\(name)'")
    } else {
        print("⚠️  Could not parse bank name")
    }
    
    // Show first 64 bytes (header)
    print("\nFirst 64 bytes (hex):")
    let header = data.prefix(64)
    for i in stride(from: 0, to: 64, by: 16) {
        let line = header[i..<min(i+16, 64)]
        let hex = line.map { String(format: "%02x", $0) }.joined(separator: " ")
        let ascii = line.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
        print(String(format: "  %04x: %-48s %@", i, hex, ascii))
    }
    
    print("\n✅ .EB2 reading works!")
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
