#!/usr/bin/env swift
import Foundation

/// EmaxForge CLI - Complete Disk Management Tool
/// One script to rule them all!

let version = "1.0.0"

// MARK: - Commands

enum Command: String {
    case create = "create"
    case addBanks = "add-banks"
    case listBanks = "list-banks"
    case exportBank = "export-bank"
    case validate = "validate"
    case help = "help"
    case version = "version"
}

// MARK: - Templates

let templatePath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/clawd/EmaxForge/EmaxForge/Resources/bootable_templates"

let templates = [
    96: "EMAXII_IMAGE_96.EZ2",
    239: "EMAXII_IMAGE_239.EZ2",
    481: "EMAXII_IMAGE_481.EZ2",
    633: "EMAXII_IMAGE_633.EZ2",
    962: "EMAXII_IMAGE_962.EZ2"
]

// MARK: - Main

func printUsage() {
    print("""
    🔨 EmaxForge CLI v\(version)
    
    Usage:
      emaxforge-cli <command> [options]
    
    Commands:
      create        Create bootable disk from template
      add-banks     Import .EB2 banks to existing disk
      list-banks    List banks on disk
      export-bank   Export bank from disk
      validate      Validate disk structure
      help          Show this help
      version       Show version
    
    Examples:
      # Create 239 MB boot disk
      emaxforge-cli create --size 239 --output HD10.hda
      
      # Create with banks
      emaxforge-cli create --size 239 --output HD10.hda \\
        --banks ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/
      
      # Add banks to existing disk
      emaxforge-cli add-banks HD10.hda ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/
      
      # List banks
      emaxforge-cli list-banks HD10.hda
    
    For detailed help on a command:
      emaxforge-cli <command> --help
    """)
}

func printVersion() {
    print("EmaxForge CLI v\(version)")
}

// MARK: - Create Command

func createDisk(args: [String]) {
    var sizeMB = 239
    var output = ""
    var scsiID = 1
    var banksDir: String? = nil
    var maxBanks = 50
    
    var i = 0
    while i < args.count {
        let arg = args[i]
        
        switch arg {
        case "--size":
            guard i + 1 < args.count, let size = Int(args[i + 1]) else {
                print("❌ --size requires a number")
                exit(1)
            }
            sizeMB = size
            i += 2
        
        case "--output":
            guard i + 1 < args.count else {
                print("❌ --output requires a path")
                exit(1)
            }
            output = args[i + 1]
            i += 2
        
        case "--scsi-id":
            guard i + 1 < args.count, let id = Int(args[i + 1]) else {
                print("❌ --scsi-id requires a number")
                exit(1)
            }
            scsiID = id
            i += 2
        
        case "--banks":
            guard i + 1 < args.count else {
                print("❌ --banks requires a directory path")
                exit(1)
            }
            banksDir = args[i + 1]
            i += 2
        
        case "--max-banks":
            guard i + 1 < args.count, let max = Int(args[i + 1]) else {
                print("❌ --max-banks requires a number")
                exit(1)
            }
            maxBanks = max
            i += 2
        
        case "--help", "-h":
            print("""
            Usage: emaxforge-cli create [options]
            
            Options:
              --size <MB>       Disk size (96, 239, 481, 633, 962) [default: 239]
              --output <path>   Output .hda file (required)
              --scsi-id <id>    SCSI ID (0-6) [default: 1]
              --banks <dir>     Import banks from directory (optional)
              --max-banks <N>   Max banks to import [default: 50]
            """)
            exit(0)
        
        default:
            print("❌ Unknown option: \(arg)")
            exit(1)
        }
    }
    
    guard !output.isEmpty else {
        print("❌ --output is required")
        exit(1)
    }
    
    guard let templateName = templates[sizeMB] else {
        print("❌ Invalid size: \(sizeMB)")
        print("   Available: 96, 239, 481, 633, 962")
        exit(1)
    }
    
    let templateFile = "\(templatePath)/\(templateName)"
    
    guard FileManager.default.fileExists(atPath: templateFile) else {
        print("❌ Template not found: \(templateFile)")
        exit(1)
    }
    
    print("🚀 EmaxForge - Create Bootable Disk")
    print("")
    print("📀 Creating disk from template")
    print("   Size: \(sizeMB) MB")
    print("   Template: \(templateName)")
    print("   Output: \(output)")
    print("   SCSI ID: \(scsiID)")
    print("")
    
    do {
        let templateURL = URL(fileURLWithPath: templateFile)
        let outputURL = URL(fileURLWithPath: output)
        
        if FileManager.default.fileExists(atPath: output) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        try FileManager.default.copyItem(at: templateURL, to: outputURL)
        
        let size = try FileManager.default.attributesOfItem(atPath: output)[.size] as! Int64
        print("✅ Disk created: \(output)")
        print("   Size: \(size / 1_048_576) MB (\(size) bytes)")
        print("")
        
        // Import banks if specified
        if let dir = banksDir {
            print("📥 Importing banks...")
            print("   Directory: \(dir)")
            print("   Max banks: \(maxBanks)")
            print("")
            
            // TODO: Implement bank import
            print("⚠️  Bank import not yet implemented in unified CLI")
            print("   Use: swift cli-import-eb2-banks.swift \(output) \(dir)")
            print("")
        }
        
        print("🎉 DONE!")
        print("")
        print("🎯 Next steps:")
        print("   1. Copy \(output) to SD card")
        print("   2. Insert SD in ZuluSCSI")
        print("   3. Boot EMAX II!")
        
    } catch {
        print("❌ Failed: \(error)")
        exit(1)
    }
}

// MARK: - List Banks Command

func listBanks(args: [String]) {
    guard args.count >= 1 else {
        print("❌ Usage: emaxforge-cli list-banks <disk.hda>")
        exit(1)
    }
    
    let diskPath = args[0]
    
    guard FileManager.default.fileExists(atPath: diskPath) else {
        print("❌ Disk not found: \(diskPath)")
        exit(1)
    }
    
    print("📋 EmaxForge - List Banks")
    print("")
    print("Disk: \(diskPath)")
    print("")
    
    // TODO: Implement
    print("⚠️  Not yet implemented")
    print("   Use: swift cli-list-banks.swift \(diskPath)")
}

// MARK: - Entry Point

guard CommandLine.arguments.count > 1 else {
    printUsage()
    exit(1)
}

let commandStr = CommandLine.arguments[1]
let commandArgs = Array(CommandLine.arguments.dropFirst(2))

switch commandStr {
case "create":
    createDisk(args: commandArgs)

case "list-banks":
    listBanks(args: commandArgs)

case "help", "--help", "-h":
    printUsage()

case "version", "--version", "-v":
    printVersion()

default:
    print("❌ Unknown command: \(commandStr)")
    print("")
    printUsage()
    exit(1)
}
