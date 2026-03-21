#!/usr/bin/env swift
import Foundation

/// EmaxForge - Create Bootable Disk from standard tools Template
/// Uses pre-made standard tools bootable templates (MUCH simpler than building from scratch!)

// MARK: - Main

struct Options {
    var sizeMB: Int = 239
    var output: String = ""
    var scsiID: Int = 1
    
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
        EmaxForge CLI - Create Bootable Disk from standard tools Template
        
        Usage:
          swift cli-create-from-template.swift [OPTIONS]
        
        Options:
          --size <MB>       Disk size (96, 239, 481, 633, 962) [default: 239]
          --output <path>   Output .hda file (required)
          --scsi-id <id>    SCSI ID (0-6) [default: 1]
          -h, --help        Show this help
        
        How it works:
          1. Copies pre-made standard tools bootable template (includes OS!)
          2. Renames to .hda for ZuluSCSI compatibility
          3. DONE! Ready to boot!
        
        Examples:
          # Boot disk (SCSI ID 1, 239 MB)
          swift cli-create-from-template.swift --size 239 --output HD10.hda --scsi-id 1
          
          # Boot disk (SCSI ID 0, 96 MB)
          swift cli-create-from-template.swift --size 96 --output HD00.hda --scsi-id 0
        
        Note:
          MUCH simpler than cli-create-disk.swift! No header building, no OS writing!
          Just copy standard tools's perfect template and rename!
        """)
    }
}

// MARK: - Template Paths

let templateBasePath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/clawd/EmaxForge/EmaxForge/Resources/bootable_templates"

let templates = [
    96: "EMAXII_IMAGE_96.EZ2",
    239: "EMAXII_IMAGE_239.EZ2",
    481: "EMAXII_IMAGE_481.EZ2",
    633: "EMAXII_IMAGE_633.EZ2",
    962: "EMAXII_IMAGE_962.EZ2"
]

// MARK: - Create Disk

func createDisk(sizeMB: Int, output: String, scsiID: Int) throws {
    guard let templateFile = templates[sizeMB] else {
        print("❌ Invalid size: \(sizeMB) MB")
        print("   Valid sizes: 96, 239, 481, 633, 962")
        exit(1)
    }
    
    let templatePath = "\(templateBasePath)/\(templateFile)"
    
    guard FileManager.default.fileExists(atPath: templatePath) else {
        print("❌ Template not found: \(templatePath)")
        print("   Run: cd ~/clawd/EmaxForge && cp ~/clawd/standard/Images/EMAX\\ II/Disk\\ Images/*.EZ2 EmaxForge/Resources/bootable_templates/")
        exit(1)
    }
    
    print("📀 Creating bootable disk from standard tools template")
    print("   Size: \(sizeMB) MB")
    print("   Template: \(templateFile)")
    print("   Output: \(output)")
    print("   SCSI ID: \(scsiID)")
    print("")
    
    // Simple copy + rename!
    try FileManager.default.copyItem(atPath: templatePath, toPath: output)
    
    let fileSize = try FileManager.default.attributesOfItem(atPath: output)[.size] as! UInt64
    let sizeMBActual = fileSize / 1024 / 1024
    
    print("✅ Created: \(output)")
    print("   Size: \(sizeMBActual) MB (\(fileSize) bytes)")
    print("   SCSI ID: \(scsiID) (filename should be HD\(scsiID)0.hda)")
    print("")
    print("🎯 This disk is READY TO BOOT on EMAX II!")
    print("   - OS included (from standard tools template)")
    print("   - Boot-tested structure")
    print("   - Add banks with: swift cli-import-bank.swift")
    
    // JSON output
    print("\nJSON_OUTPUT_START")
    print("""
    {
      "success" : true,
      "path" : "\(output)",
      "size" : \(fileSize),
      "scsi_id" : \(scsiID),
      "bootable" : true,
      "template" : "\(templateFile)"
    }
    """)
    print("JSON_OUTPUT_END")
}

// MARK: - Run

guard let options = Options.parse(CommandLine.arguments) else {
    Options.printUsage()
    exit(0)
}

do {
    try createDisk(sizeMB: options.sizeMB, output: options.output, scsiID: options.scsiID)
} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}
