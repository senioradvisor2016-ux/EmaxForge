import SwiftUI

struct RenameImageSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let image: DiskImage
    
    @State private var scsiID: Int
    @State private var imageIndex: Int
    @State private var label: String
    @State private var useImageIndex: Bool
    @State private var errorMessage: String?
    
    init(image: DiskImage) {
        self.image = image
        _scsiID = State(initialValue: image.scsiID ?? 1)
        _imageIndex = State(initialValue: image.imageIndex ?? 0)
        _label = State(initialValue: image.label ?? "")
        _useImageIndex = State(initialValue: image.imageIndex != nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Rename Image",
                subtitle: image.filename,
                icon: "pencil",
                onClose: { dismiss() }
            )
            
            Divider()
            
            Form {
                Section("SCSI Configuration") {
                    Picker("SCSI ID", selection: $scsiID) {
                        ForEach(0...appState.currentDevice.maxScsiID, id: \.self) { id in
                            Text("ID \(id)").tag(id)
                        }
                    }
                    
                    Toggle("Multi-image slot", isOn: $useImageIndex)
                    
                    if useImageIndex {
                        Stepper("Image index: \(imageIndex)", value: $imageIndex, in: 0...99)
                    }
                    
                    TextField("Label (optional)", text: $label)
                }
                
                Section("Preview") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(image.filename)
                                .foregroundStyle(.secondary)
                                .strikethrough()
                            Text(previewFilename)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.accent)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .formStyle(.grouped)
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Rename") { rename() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding()
        }
        .frame(width: 440, height: 380)
        .onExitCommand { dismiss() }
    }
    
    private var previewFilename: String {
        var name = "\(appState.currentDevice.scsiPrefix)\(scsiID)"
        if useImageIndex { name += "_\(imageIndex)" }
        if !label.isEmpty { name += "_\(label)" }
        name += ".hda"
        return name
    }
    
    private func rename() {
        do {
            _ = try appState.fileService.renameImage(
                image,
                scsiID: scsiID,
                imageIndex: useImageIndex ? imageIndex : nil,
                label: label.isEmpty ? nil : label
            )
            appState.selectedImage = nil
            appState.refreshImages()
            appState.statusMessage = "Renamed → \(previewFilename)"
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
