import SwiftUI

struct DuplicateImageSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let image: DiskImage
    
    @State private var scsiID: Int
    @State private var imageIndex: Int
    @State private var label: String
    @State private var useImageIndex = true
    @State private var targetVolume: DuplicateTarget = .sameVolume
    @State private var customURL: URL?
    @State private var progress: Double?
    @State private var errorMessage: String?
    
    enum DuplicateTarget: String, CaseIterable {
        case sameVolume = "Same location"
        case chooseFolder = "Choose folder…"
    }
    
    init(image: DiskImage) {
        self.image = image
        _scsiID = State(initialValue: image.scsiID ?? 1)
        _imageIndex = State(initialValue: (image.imageIndex ?? 0) + 1)
        _label = State(initialValue: image.label ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Duplicate Image",
                subtitle: "\(image.filename) (\(image.formattedSize))",
                icon: "doc.on.doc",
                onClose: { dismiss() }
            )
            
            Divider()
            
            Form {
                Section("Destination") {
                    Picker("Location", selection: $targetVolume) {
                        ForEach(DuplicateTarget.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .onChange(of: targetVolume) { _, newValue in
                        if newValue == .chooseFolder { pickFolder() }
                    }
                    
                    if let url = customURL {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(url.lastPathComponent)
                        }
                    }
                }
                
                Section("SCSI Configuration") {
                    Picker("SCSI ID", selection: $scsiID) {
                        ForEach(0...appState.currentDevice.maxScsiID, id: \.self) { id in
                            Text("ID \(id)").tag(id)
                        }
                    }
                    
                    Toggle("Image index", isOn: $useImageIndex)
                    if useImageIndex {
                        Stepper("Index: \(imageIndex)", value: $imageIndex, in: 0...99)
                    }
                    
                    TextField("Label", text: $label)
                }
                
                Section("Preview") {
                    HStack {
                        Text("New name")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(previewFilename)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .formStyle(.grouped)
            
            if let p = progress {
                ProgressView(value: p)
                    .padding(.horizontal)
                    .tint(Theme.accent)
            }
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Duplicate") { duplicate() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(progress != nil)
            }
            .padding()
        }
        .frame(width: 460, height: 480)
        .onExitCommand { dismiss() }
    }
    
    private var previewFilename: String {
        var name = "\(appState.currentDevice.scsiPrefix)\(scsiID)"
        if useImageIndex { name += "_\(imageIndex)" }
        if !label.isEmpty { name += "_\(label)" }
        name += ".hda"
        return name
    }
    
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            customURL = panel.url
        } else {
            targetVolume = .sameVolume
        }
    }
    
    private func duplicate() {
        let destDir: URL
        switch targetVolume {
        case .sameVolume:
            destDir = image.url.deletingLastPathComponent()
        case .chooseFolder:
            guard let url = customURL else { return }
            destDir = url
        }
        
        progress = 0.3
        errorMessage = nil
        
        DispatchQueue.global().async {
            do {
                let result = try appState.fileService.copyImage(
                    image,
                    to: destDir,
                    scsiID: scsiID,
                    imageIndex: useImageIndex ? imageIndex : nil,
                    label: label.isEmpty ? nil : label
                )
                
                DispatchQueue.main.async {
                    progress = 1.0
                    appState.refreshImages()
                    appState.statusMessage = "Duplicated → \(result.lastPathComponent)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
                }
            } catch {
                DispatchQueue.main.async {
                    progress = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
