import Foundation

/// Service for creating EMAX II bank templates
class BankTemplateService {
    
    struct Template: Identifiable {
        let id: String  // Use name as ID
        let name: String
        let description: String
        let presets: Int
    }
    
    /// Get list of available templates
    static func listTemplates() async throws -> [Template] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["cli-anything-emaxforge", "list-templates", "--json"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let json = try JSONDecoder().decode(TemplateListResponse.self, from: data)
        
        return json.templates.map { tmpl in
            Template(
                id: tmpl.name,
                name: tmpl.name,
                description: tmpl.description,
                presets: tmpl.presets
            )
        }
    }
    
    struct CreateResult {
        let file: String
        let size: Int
        let presets: Int
    }
    
    /// Create bank from template
    /// - Parameters:
    ///   - template: Template name (INIT, PERCUSSION, etc.)
    ///   - output: Output .EB2 file path
    ///   - name: Optional custom bank name
    ///   - presetCount: Optional preset count (for EMPTY template)
    static func createTemplate(
        template: String,
        output: URL,
        name: String? = nil,
        presetCount: Int? = nil
    ) async throws -> CreateResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        var args = ["cli-anything-emaxforge", "create-template", template, output.path, "--json"]
        
        if let name = name {
            args.append(contentsOf: ["--name", name])
        }
        
        if let count = presetCount {
            args.append(contentsOf: ["--preset-count", "\(count)"])
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let json = try JSONDecoder().decode(CreateResponse.self, from: data)
        
        return CreateResult(
            file: json.file,
            size: json.size,
            presets: json.presets
        )
    }
    
    // MARK: - Codable Models
    
    private struct TemplateListResponse: Codable {
        let templates: [TemplateResponse]
        let count: Int
    }
    
    private struct TemplateResponse: Codable {
        let name: String
        let description: String
        let presets: Int
    }
    
    private struct CreateResponse: Codable {
        let file: String
        let size: Int
        let presets: Int
        let samples: Int
    }
}
