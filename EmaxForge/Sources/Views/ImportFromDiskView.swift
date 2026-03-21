import SwiftUI

struct ImportFromDiskView: View {
    @Environment(\.dismiss) private var dismiss
    let targetImageURL: URL
    
    @State private var sourceDiskURL: URL?
    @State private var availableBanks: [BankExtractor.ExtractedBank] = []
    @State private var selectedBanks: Set<String> = []
    @State private var isScanning = false
    @State private var isImporting = false
    @State private var statusMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import Native Banks from standard tools Disk")
                .font(.headline)
            
            Text("Extract banks from standard .EZ2/.HDA disks")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Source disk selection
            HStack {
                if let url = sourceDiskURL {
                    Text(url.lastPathComponent)
                        .truncationMode(.middle)
                } else {
                    Text("No disk selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Choose Disk...") {
                    chooseSourceDisk()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Bank list
            if isScanning {
                ProgressView("Scanning disk...")
            } else if !availableBanks.isEmpty {
                List(availableBanks, id: \.name, selection: $selectedBanks) { bank in
                    HStack {
                        Text(bank.name)
                        Spacer()
                        Text("\(bank.clusterCount) clusters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 300)
                
                Text("\(selectedBanks.count) of \(availableBanks.count) banks selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if sourceDiskURL != nil {
                Text("No banks found on disk")
                    .foregroundColor(.secondary)
            }
            
            // Status
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !availableBanks.isEmpty {
                    Button("Select All") {
                        selectedBanks = Set(availableBanks.map(\.name))
                    }
                    .disabled(selectedBanks.count == availableBanks.count)
                    
                    Button("Import Selected") {
                        importSelectedBanks()
                    }
                    .disabled(selectedBanks.isEmpty || isImporting)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .alert("Import Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func chooseSourceDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "EZ2")!, .init(filenameExtension: "hda")!]
        panel.allowsMultipleSelection = false
        panel.message = "Choose disk image to extract banks from"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourceDiskURL = url
            scanDisk(url)
        }
    }
    
    private func scanDisk(_ url: URL) {
        isScanning = true
        statusMessage = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let banks = try BankExtractor.extractAllBanks(from: url)
                
                DispatchQueue.main.async {
                    availableBanks = banks
                    isScanning = false
                    statusMessage = "Found \(banks.count) banks"
                }
            } catch {
                DispatchQueue.main.async {
                    isScanning = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func importSelectedBanks() {
        isImporting = true
        statusMessage = "Importing \(selectedBanks.count) banks..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var imported = 0
            
            for bank in availableBanks where selectedBanks.contains(bank.name) {
                do {
                    // Save as .raw file temporarily
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(bank.name).raw")
                    try bank.data.write(to: tempURL)
                    
                    // Import using BankImporter
                    _ = try BankImporter.importBank(eb2URL: tempURL, into: targetImageURL)
                    
                    // Clean up
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    imported += 1
                } catch {
                    print("⚠️  Failed to import \(bank.name): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                isImporting = false
                statusMessage = "Imported \(imported) banks successfully"
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
    }
}
