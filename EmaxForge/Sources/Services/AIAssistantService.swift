import Foundation
import Combine

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date
    
    enum Role: String {
        case user
        case assistant
        case system
    }
    
    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
}

// MARK: - Anthropic API Types

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let stream: Bool
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

// Streaming event types
private struct StreamEvent: Decodable {
    let type: String
    let delta: Delta?
    
    struct Delta: Decodable {
        let type: String?
        let text: String?
    }
}

// MARK: - Connection State

enum AIConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Config

private struct AIConfig: Decodable {
    let api_key: String
}

// MARK: - AI Assistant Service

@MainActor
class AIAssistantService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var connectionState: AIConnectionState = .disconnected
    @Published var currentStreamingText = ""
    
    private var apiKey: String = ""
    private let modelName = "claude-sonnet-4-20250514"
    private let maxHistoryMessages = 20
    private let manualSearch = ManualSearchService()
    
    // App context
    var volumePath: String?
    var loadedImages: [(name: String, size: Int64, scsiID: Int)] = []
    var deviceType: String = "EMAX II"
    
    init() {
        loadAPIKey()
        manualSearch.loadManuals()
    }
    
    private func loadAPIKey() {
        let configPath = NSString("~/.emaxforge/config.json").expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(AIConfig.self, from: data) else {
            connectionState = .error("No API key")
            return
        }
        apiKey = config.api_key
        connectionState = .connected
    }
    
    // MARK: - Connection Check
    
    func checkConnection() async {
        if apiKey.isEmpty {
            loadAPIKey()
        }
        connectionState = apiKey.isEmpty ? .error("No API key") : .connected
    }
    
    // MARK: - System Prompt
    
    private func buildSystemPrompt() -> String {
        var prompt = """
        You are the EmaxForge AI Assistant — an expert on E-mu EMAX II, ZuluSCSI, Gotek, \
        and vintage sampler disk management. You help users with their EMAX II setup, \
        troubleshooting, and disk image management.
        
        Be concise, practical, and friendly. Use bullet points for steps. \
        Answer in the same language the user writes in. \
        If you're unsure, say so rather than guessing.
        
        ## Knowledge Base
        
        ### Boot Requirements
        The EMAX II ALWAYS boots from SCSI ID 1 (HD1). This is hardcoded in hardware.
        - File must be named HD10.hda (or HD10_0.hda for multi-image)
        - The disk must contain the EMAX II OS (.EMX file)
        - Recommended OS: v2.14 (latest, most stable)
        - Common mistake: Only having HD00.hda without HD10 → won't boot
        - Correct setup: HD10.hda (boot+OS, SCSI 1) + HD20.hda (data, SCSI 2)
        
        ### File Formats
        - .EZ2 — EMAX II HD image (EMXP format). IDENTICAL to .hda — just rename!
        - .EB2 — EMAX II Bank file (presets + samples)
        - .EMX — EMAX II OS file
        - .hda — Raw HD image for ZuluSCSI
        - ⚠️ NEVER use `dd skip=1` — this corrupts EMAX II images!
        
        ### ZuluSCSI Naming
        - HDx.hda where x = SCSI ID (0-6)
        - Multi-image: HDx_y_label.hda (y = index, label = optional)
        - Button press cycles images for active SCSI ID
        - SCSI ID 7 is reserved for host — don't use
        
        ### SCSI Termination
        - Terminate both ends of the SCSI chain
        - EMAX II (terminated) ↔ ZuluSCSI (terminated) = correct
        - With Gotek: EMAX II (term) ↔ Gotek (NO term) ↔ ZuluSCSI (term)
        - Bad termination → drive not detected, random errors, data corruption
        
        ### SD Card Tips
        - Format: FAT32 (mandatory), max 32 GB recommended
        - Speed: Class 10 / UHS-I minimum
        - macOS: Disk Utility → Erase → MS-DOS (FAT32) → Master Boot Record
        - Don't use exFAT — ZuluSCSI needs FAT32
        
        ### Troubleshooting
        - Drive not seen: Check SCSI cable, termination, SCSI ID conflicts
        - "Disk Error": Image corrupted, check block alignment (512-byte multiples)
        - Slow boot: Normal (SCSI enumeration), reduce StartupDelay in zuluscsi.ini
        - Image switching: Must follow HDx_y naming convention
        
        ### EMXP-Compatible Disk Sizes
        Standard sizes: 96 MB, 239 MB, 481 MB, 633 MB, 962 MB
        Default: 239 MB. These match EMXP v3.11 exactly.
        
        ### EmaxForge Features
        - Create bootable disks (Bootable Disk Wizard ⇧⌘B)
        - Import .EB2 banks into disk images
        - Format disks (HD, SD, Floppy)
        - Create Gotek floppy images (.img, .hfe)
        - Multi-disk setup (HD10 boot + HD20/HD30 data)
        - ZuluSCSI configuration management
        
        ### EMAX II Hardware Basics
        - 16-bit sampler, 8-voice polyphony (expandable to 16)
        - 1 MB sample RAM standard (expandable to 4 MB)
        - 50-pin SCSI connector for hard drives
        - Built-in 3.5" floppy drive (800 KB DD format)
        - Loading banks: LOAD → select source → select bank
        - Saving: SAVE → select destination → name → confirm
        - Digital processing: filters, LFOs, envelopes per voice
        """
        
        // Add live app context
        if volumePath != nil || !loadedImages.isEmpty {
            prompt += "\n\n## Current Session Context\n"
            prompt += "Device: \(deviceType)\n"
            
            if let vol = volumePath {
                prompt += "Volume: \(vol)\n"
            }
            
            if !loadedImages.isEmpty {
                prompt += "Loaded images:\n"
                for img in loadedImages {
                    let sizeMB = img.size / (1024 * 1024)
                    prompt += "- \(img.name) (\(sizeMB) MB, SCSI ID \(img.scsiID))\n"
                }
            }
        }
        
        return prompt
    }
    
    // MARK: - Send Message
    
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text, timestamp: Date())
        messages.append(userMessage)
        
        // Placeholder for assistant response
        let assistantMessage = ChatMessage(role: .assistant, content: "", timestamp: Date())
        messages.append(assistantMessage)
        
        isStreaming = true
        currentStreamingText = ""
        
        guard !apiKey.isEmpty else {
            updateLastAssistantMessage("❌ No API key found.\n\nCreate `~/.emaxforge/config.json`:\n```\n{\"api_key\": \"sk-ant-...\"}\n```")
            isStreaming = false
            return
        }
        
        // Build messages (exclude empty placeholder)
        var apiMessages: [AnthropicMessage] = []
        let historyMessages = Array(messages.dropLast().suffix(maxHistoryMessages))
        for msg in historyMessages {
            guard msg.role != .system else { continue }
            apiMessages.append(AnthropicMessage(role: msg.role.rawValue, content: msg.content))
        }
        
        // Search manuals for relevant context based on user query
        let systemPrompt: String
        if let manualContext = manualSearch.contextForQuery(text) {
            systemPrompt = buildSystemPrompt() + manualContext
        } else {
            systemPrompt = buildSystemPrompt()
        }
        
        let requestBody = AnthropicRequest(
            model: modelName,
            max_tokens: 2048,
            system: systemPrompt,
            messages: apiMessages,
            stream: true
        )
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            updateLastAssistantMessage("❌ Invalid API URL")
            isStreaming = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            updateLastAssistantMessage("❌ Failed to encode request")
            isStreaming = false
            return
        }
        
        // Stream the response (SSE)
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // Read error body
                var errorBody = ""
                for try await line in bytes.lines {
                    errorBody += line
                    if errorBody.count > 500 { break }
                }
                updateLastAssistantMessage("❌ API error (\(httpResponse.statusCode)): \(errorBody.prefix(200))")
                isStreaming = false
                return
            }
            
            var fullText = ""
            
            for try await line in bytes.lines {
                // SSE format: "data: {...}"
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                
                guard jsonStr != "[DONE]",
                      let data = jsonStr.data(using: .utf8),
                      let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else {
                    continue
                }
                
                if event.type == "content_block_delta",
                   let text = event.delta?.text {
                    fullText += text
                    currentStreamingText = fullText
                    updateLastAssistantMessage(fullText)
                }
                
                if event.type == "message_stop" {
                    break
                }
            }
            
            if fullText.isEmpty {
                updateLastAssistantMessage("⚠️ No response from Claude. Try again.")
            }
            
        } catch is CancellationError {
            // User navigated away
        } catch {
            let errorMsg = error.localizedDescription
            updateLastAssistantMessage("❌ Error: \(errorMsg)")
        }
        
        isStreaming = false
        currentStreamingText = ""
    }
    
    // MARK: - Helpers
    
    private func updateLastAssistantMessage(_ text: String) {
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].role == .assistant else { return }
        messages[lastIndex].content = text
    }
    
    func clearHistory() {
        messages.removeAll()
    }
}
