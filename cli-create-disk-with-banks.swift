#!/usr/bin/env swift
import Foundation

/// EmaxForge CLI - Create Disk with Banks
/// Creates bootable disk from template + imports .EB2 banks automatically

print("🚀 EmaxForge - Create Disk with Banks\n")

// MARK: - Arguments

struct Options {
    var sizeMB: Int = 239
    var output: String = ""
    var scsiID: Int = 1
    var banksDir: String = ""
    var maxBanks: Int = 50
    
    static func parse(_ args: [String]) -> Options? {
        var result = Options()
        var i = 1
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--size":
                guard i + 1 < args.count, let size = Int(args[i + 1]) else { return nil }
                result.sizeMB = size
                i += 2
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
                i += 2
            
            case "--scsi-id":
                guard i + 1 < args.count, let id = Int(args[i + 1]) else { return nil }
                result.scsiID = id
                i += 2
            
            case "--banks":
                guard i + 1 < args.count else { return nil }
                result.banksDir = args[i + 1]
                i += 2
            
            case "--max-banks":
                guard i + 1 < args.count, let max = Int(args[i + 1]) else { return nil }
                result.maxBanks = max
                i += 2
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.output.isEmpty else {
            print("❌ --output required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        Usage:
          swift cli-create-disk-with-banks.swift [OPTIONS]
        
        Options:
          --size <MB>       Disk size (96, 239, 481, 633, 962) [default: 239]
          --output <path>   Output .hda file (required)
          --scsi-id <id>    SCSI ID (0-6) [default: 1]
          --banks <dir>     Directory with .EB2 banks (optional)
          --max-banks <N>   Max banks to import [default: 50]
          -h, --help        Show this help
        
        Examples:
          # Just bootable disk (no banks)
          swift cli-create-disk-with-banks.swift --size 239 --output HD10.hda
          
          # Disk with banks
          swift cli-create-disk-with-banks.swift \\
            --size 239 \\
            --output HD10.hda \\
            --banks ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/ \\
            --max-banks 50
        
          # Small boot disk (96 MB, SCSI ID 0)
          swift cli-create-disk-with-banks.swift --size 96 --output HD00.hda --scsi-id 0
        """)
    }
}

guard let options = Options.parse(CommandLine.arguments) else {
    Options.printUsage()
    exit(1)
}

// MARK: - Create Base Disk

print("📀 Step 1: Creating bootable disk from template")
print("   Size: \(options.sizeMB) MB")
print("   Template: EMAXII_IMAGE_\(options.sizeMB).EZ2")
print("   Output: \(options.output)")
print("")

let templatePath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/clawd/EmaxForge/EmaxForge/Resources/bootable_templates/EMAXII_IMAGE_\(options.sizeMB).EZ2"

guard FileManager.default.fileExists(atPath: templatePath) else {
    print("❌ Template not found: \(templatePath)")
    print("   Available sizes: 96, 239, 481, 633, 962")
    exit(1)
}

do {
    let templateURL = URL(fileURLWithPath: templatePath)
    let outputURL = URL(fileURLWithPath: options.output)
    
    // Copy template
    if FileManager.default.fileExists(atPath: options.output) {
        try FileManager.default.removeItem(at: outputURL)
    }
    
    try FileManager.default.copyItem(at: templateURL, to: outputURL)
    
    let size = try FileManager.default.attributesOfItem(atPath: options.output)[.size] as! Int64
    print("✅ Base disk created: \(options.output)")
    print("   Size: \(size / 1_048_576) MB (\(size) bytes)")
    print("")
    
} catch {
    print("❌ Failed to create disk: \(error)")
    exit(1)
}

// MARK: - Import Banks

if !options.banksDir.isEmpty {
    print("📥 Step 2: Importing banks")
    print("   Banks directory: \(options.banksDir)")
    print("   Max banks: \(options.maxBanks)")
    print("")
    
    let banksURL = URL(fileURLWithPath: options.banksDir)
    
    guard FileManager.default.fileExists(atPath: options.banksDir) else {
        print("❌ Banks directory not found: \(options.banksDir)")
        exit(1)
    }
    
    // Find .EB2 files
    let eb2Files: [URL]
    do {
        eb2Files = try FileManager.default.contentsOfDirectory(at: banksURL, includingPropertiesForKeys: [.fileSizeKey])
            .filter { $0.pathExtension.uppercased() == "EB2" }
            .filter { url in
                // Only import banks < 2 MB
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    return size < 2_000_000
                }
                return true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .prefix(options.maxBanks)
            .map { $0 }
    } catch {
        print("❌ Failed to read banks directory: \(error)")
        exit(1)
    }
    
    if eb2Files.isEmpty {
        print("⚠️  No .EB2 files found in \(options.banksDir)")
        print("")
    }
    
    if !eb2Files.isEmpty {
        print("📂 Found \(eb2Files.count) .EB2 banks")
        print("")
        
        // Call cli-import-eb2-banks.swift
        let importScript = "\(FileManager.default.homeDirectoryForCurrentUser.path)/clawd/EmaxForge/cli-import-eb2-banks.swift"
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        task.arguments = [importScript, options.output, options.banksDir, String(options.maxBanks)]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
                print("✅ Banks imported successfully!")
            } else {
                print("⚠️  Bank import had issues (exit code: \(task.terminationStatus))")
            }
        } catch {
            print("⚠️  Failed to run import script: \(error)")
        }
    }
} else {
    print("ℹ️  No banks directory specified (use --banks to add banks)")
}

print("")
print("🎉 DONE!")
print("   Disk: \(options.output)")
print("   SCSI ID: \(options.scsiID) (filename should be HD\(options.scsiID)0.hda)")
print("")
print("🎯 Copy to SD card and test on EMAX II!")
