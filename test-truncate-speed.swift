#!/usr/bin/env swift
import Foundation

let testPath = "/tmp/truncate-test.bin"
let size: UInt64 = 250_398_720  // 239 MB

print("🕐 Testing truncate speed on 239 MB file...")
print("")

let start = Date()

print("Creating file...")
FileManager.default.createFile(atPath: testPath, contents: nil)

print("Opening handle...")
let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: testPath))

print("Truncating to \(size) bytes...")
try handle.truncate(atOffset: size)

handle.closeFile()

let elapsed = Date().timeIntervalSince(start)
print("")
print("✅ Done in \(String(format: "%.2f", elapsed)) seconds")

try? FileManager.default.removeItem(atPath: testPath)
