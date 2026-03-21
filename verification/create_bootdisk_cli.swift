#!/usr/bin/env swift
import Foundation

// EmaxForge Boot Disk Creator CLI
// Usage: swift create_bootdisk_cli.swift <output_path> <os_path>

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let emaxforgeRoot = scriptDir.deletingLastPathComponent()
let sourcesDir = emaxforgeRoot.appendingPathComponent("EmaxForge/Sources")

// Import EmaxForge services
let imageCreatorPath = sourcesDir.appendingPathComponent("Services/ImageCreator.swift")
let formatPresetPath = sourcesDir.appendingPathComponent("Models/FormatPreset.swift")
let templatePath = sourcesDir.appendingPathComponent("Models/ImageTemplate.swift")

// Load sources (simplified — real version needs full SPM import)
guard FileManager.default.fileExists(atPath: imageCreatorPath.path) else {
    print("ERROR: ImageCreator.swift not found at \(imageCreatorPath.path)")
    exit(1)
}

// For now: use EmaxForge CLI harness
let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Usage: \(URL(fileURLWithPath: args[0]).lastPathComponent) <output_path> <os_path>")
    exit(1)
}

let outputPath = args[1]
let osPath = args[2]

// Use EmaxForge binary if available
let emaxforgeBinary = emaxforgeRoot.appendingPathComponent(".build/EmaxForge.app/Contents/MacOS/EmaxForge")

if !FileManager.default.fileExists(atPath: emaxforgeBinary.path) {
    print("ERROR: EmaxForge binary not found. Run ./build.sh first")
    exit(1)
}

print("Creating boot disk via EmaxForge binary...")
print("Output: \(outputPath)")
print("OS: \(osPath)")

// TODO: Implement via Swift or use agent-harness CLI when ready
print("TODO: Implement boot disk creation")
print("For now, use: cli-anything-emaxforge create-boot-disk ...")
exit(0)
