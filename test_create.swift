#!/usr/bin/env swift

// Test: Create boot disk using EmaxForge's actual ImageCreator + BankImporter code
// Then verify against _IMAGE_239.EZ2 reference

import Foundation

// We need to compile with the actual source files
// This script is run via: swift test_create.swift (after build)

// Since we can't import the app module directly, let's use the built app's code
// by calling the same logic via a small test binary

print("=== EmaxForge Disk Creation Test ===")
print("")

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser.path
let testOutput = "\(home)/Desktop/TEST_EMAXFORGE.hda"
let refPath = "\(home)/clawd/EmaxForge/_IMAGE_239.EZ2"
let eb2Dir = "\(home)/Desktop/EMAX-BANKS"

// Clean up
try? fm.removeItem(atPath: testOutput)

print("Creating boot disk at: \(testOutput)")
print("Will verify against: \(refPath)")
print("")
