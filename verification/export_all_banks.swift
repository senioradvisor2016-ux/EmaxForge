#!/usr/bin/env swift

import Foundation

// Import EmaxForge modules
let projectRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
let sourcesPath = projectRoot.appendingPathComponent("EmaxForge/Sources")

// Load BankExtractor
let extractorSource = try! String(contentsOf: sourcesPath.appendingPathComponent("Services/BankExtractor.swift"))
eval(extractorSource)  // ❌ Can't eval Swift dynamically

// ALTERNATIVE: Build a CLI tool
print("❌ Swift scripts can't import local modules directly")
print("✅ Building CLI export tool instead...")
print("")

// Create a proper CLI tool
let cliPath = projectRoot.appendingPathComponent("verification/export_cli")
try! """
import Foundation

// Paste BankExtractor.swift here inline
\(try! String(contentsOf: sourcesPath.appendingPathComponent("Services/BankExtractor.swift")))

// Main CLI
guard CommandLine.arguments.count == 3 else {
    print("Usage: export_cli <image.EZ2> <output_dir>")
    exit(1)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])
try! FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("📦 Exporting all banks from \\(imageURL.lastPathComponent)...")
let banks = try! BankExtractor.extractAllBanks(from: imageURL)
print("Found \\(banks.count) banks")

for bank in banks {
    let outputURL = outputDir.appendingPathComponent(bank.name + ".EB2")
    try! bank.data.write(to: outputURL)
    print("  ✅ \\(bank.name) → \\(outputURL.lastPathComponent) (\\(bank.data.count) bytes)")
}

print("")
print("✅ Exported \\(banks.count) banks to \\(outputDir.path)")
""".write(to: cliPath.appendingPathExtension("swift"), atomically: true, encoding: .utf8)

print("Created: \(cliPath.path).swift")
print("Run: swift \(cliPath.path).swift <image> <output>")
