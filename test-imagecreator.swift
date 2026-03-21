#!/usr/bin/env swift
// Test EmaxForge's ImageCreator directly
import Foundation

// Load source files (this is a hack but works for testing)
let sourceDir = FileManager.default.currentDirectoryPath + "/EmaxForge/Sources"

// We need to compile the whole module, so let's just verify the .app works instead
print("Testing via compiled EmaxForge.app...")

// Check if ImageCreator would create correct disk by inspecting generated file
let testURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Desktop/EMAXFORGE-APP-TEST.hda")

print("Create a boot disk via EmaxForge app wizard")
print("Save to: \(testURL.path)")
print("")
print("Then run comparison script...")
