// Standalone test: uses ImageCreator + BankImporter source directly

import Foundation

@main
struct TestCLI {
    static func main() throws {
        try run()
    }
    
    static func run() throws {

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser.path
let testOutput = URL(fileURLWithPath: "\(home)/Desktop/TEST_EMAXFORGE.hda")
let eb2Dir = "\(home)/Desktop/EMAX-BANKS"
let refPath = "\(home)/clawd/EmaxForge/_IMAGE_239.EZ2"

// Clean
try? fm.removeItem(at: testOutput)

// Step 1: Create bootable image
print("Step 1: Creating bootable 239MB image...")
do {
    try ImageCreator.createBootableImage(at: testOutput, sizeMB: 239)
    print("  ✅ Image created: \(testOutput.lastPathComponent)")
} catch {
    print("  ❌ Failed: \(error)")
    exit(1)
}

// Step 2: Import banks
print("\nStep 2: Importing banks...")
let eb2URL = URL(fileURLWithPath: eb2Dir)
if fm.fileExists(atPath: eb2Dir) {
    let eb2Files = try! fm.contentsOfDirectory(at: eb2URL, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.uppercased() == "EB2" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    
    print("  Found \(eb2Files.count) .EB2 files")
    for eb2 in eb2Files {
        do {
            let result = try BankImporter.importBank(eb2URL: eb2, into: testOutput)
            print("  ✅ \(result.bankName): \(result.clustersUsed) clusters")
        } catch {
            print("  ❌ \(eb2.lastPathComponent): \(error)")
        }
    }
} else {
    print("  ⚠️  No EMAX-BANKS directory found")
}

// Step 3: Verify against reference
print("\nStep 3: Verifying against _IMAGE_239.EZ2...")
let testData = try! Data(contentsOf: testOutput)
let refData = try! Data(contentsOf: URL(fileURLWithPath: refPath))

struct Region {
    let name: String
    let offset: Int
    let size: Int
}

let regions: [Region] = [
    Region(name: "Header (0x000)", offset: 0, size: 512),
    Region(name: "Status (0x200)", offset: 0x200, size: 512),
    Region(name: "FAT (0x400)", offset: 0x400, size: 1024),
    Region(name: "BNT start (0x1000)", offset: 0x1000, size: 512),
    Region(name: "Catalog (0xC400)", offset: 0xC400, size: 4896),
    Region(name: "OS (0xD720)", offset: 0xD720, size: 512),
]

for r in regions {
    let test = testData[r.offset..<(r.offset + r.size)]
    let ref = refData[r.offset..<(r.offset + r.size)]
    if test == ref {
        print("  ✅ \(r.name): IDENTICAL")
    } else {
        var diffs = 0
        for i in 0..<r.size {
            if test[test.startIndex + i] != ref[ref.startIndex + i] { diffs += 1 }
        }
        print("  ❌ \(r.name): \(diffs)/\(r.size) bytes differ")
    }
}

// Check OS data specifically
let osRef = Array(refData[0xD720..<(0xD720+16)])
let osTest = Array(testData[0xD720..<(0xD720+16)])
print("\n  OS ref:  \(osRef.map { String(format: "%02x", $0) }.joined())")
print("  OS test: \(osTest.map { String(format: "%02x", $0) }.joined())")

// Check bank data at cluster 2
let bankRef = Array(refData[0x84F20..<(0x84F20+16)])
let bankTest = Array(testData[0x84F20..<(0x84F20+16)])
print("\n  Bank@cl2 ref:  \(bankRef.map { String(format: "%02x", $0) }.joined())")
print("  Bank@cl2 test: \(bankTest.map { String(format: "%02x", $0) }.joined())")

// FAT comparison
print("\n  FAT entries:")
for i in 0..<15 {
    let rv = UInt16(refData[0x400 + i*2]) | (UInt16(refData[0x401 + i*2]) << 8)
    let tv = UInt16(testData[0x400 + i*2]) | (UInt16(testData[0x401 + i*2]) << 8)
    let match = rv == tv ? "✅" : "❌"
    print("    \(match) FAT[\(i)]: ref=0x\(String(format: "%04X", rv)) test=0x\(String(format: "%04X", tv))")
}

print("\n✅ Test complete! Image at: \(testOutput.path)")
print("Size: \(testData.count) bytes")


    } // end run
} // end TestCLI
