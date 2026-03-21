#!/usr/bin/env swift

import Foundation

// EMXP Verification Script
// Exporterar alla banker från disk-image och jämför med EMXP gold standard

let emxpGoldPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/EmaxForge/verification/emxp-gold")
let emaxforgeOutputPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/EmaxForge/verification/emaxforge-output")
let diskImagePath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/emxp/Images/EmaxII-02.EZ2")

print("🔍 EMXP Verification Suite")
print("=" * 60)
print("Disk image: \(diskImagePath.lastPathComponent)")
print("EMXP gold:  \(try! FileManager.default.contentsOfDirectory(atPath: emxpGoldPath.path).filter { $0.hasSuffix(".EB2") }.count) banker")
print("")

// TODO: Implementera BankExporter.exportAllBanks(from: diskImagePath, to: emaxforgeOutputPath)
print("❌ BankExporter.exportAllBanks() inte implementerat än")
print("   → Nästa steg: Implementera i BankExporter.swift")
