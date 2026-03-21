import Foundation

// Quick test script to create a boot disk with current ImageCreator
let testDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/EmaxForge/test-new-boot")

try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

let diskURL = testDir.appendingPathComponent("HD00.hda")

print("Creating boot disk at: \(diskURL.path)")
print("Using OS file: \(ImageCreator.osFilePath?.path ?? "NOT FOUND")")

// This would require importing the whole EmaxForge module...
// Let's just test from the app instead
print("Run from EmaxForge app GUI instead")
