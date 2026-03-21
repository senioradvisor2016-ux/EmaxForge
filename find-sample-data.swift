#!/usr/bin/env swift
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: url)

// Sample data is typically raw PCM audio
// Look for regions with high entropy (not all 0xFF or 0x00)

func entropy(_ bytes: Data) -> Double {
    var counts = [UInt8: Int]()
    for byte in bytes {
        counts[byte, default: 0] += 1
    }
    
    var entropy = 0.0
    let n = Double(bytes.count)
    for count in counts.values {
        let p = Double(count) / n
        if p > 0 {
            entropy -= p * log2(p)
        }
    }
    return entropy
}

let chunkSize = 1024
var highEntropyRegions: [(offset: Int, entropy: Double)] = []

for offset in stride(from: 0, to: data.count - chunkSize, by: chunkSize) {
    let chunk = data.subdata(in: offset..<offset+chunkSize)
    let e = entropy(chunk)
    
    if e > 6.0 {  // High entropy = likely sample data
        highEntropyRegions.append((offset: offset, entropy: e))
    }
}

print("High entropy regions (likely sample data):")
for (i, region) in highEntropyRegions.prefix(10).enumerated() {
    let hexOffset = String(format: "0x%06X", region.offset)
    print("[\(i)] Offset: \(hexOffset), Entropy: \(String(format: "%.2f", region.entropy))")
}

print("\nTotal high-entropy regions: \(highEntropyRegions.count)")
print("File size: \(data.count) bytes")

if let first = highEntropyRegions.first {
    print("\nFirst sample data likely starts at: 0x\(String(format: "%06X", first.offset))")
}
