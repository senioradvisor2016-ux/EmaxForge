import SwiftUI

/// Batch rename all images on a volume to proper ZuluSCSI naming
struct BatchRenameView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var assignments: [ImageAssignment] = []
    @State private var errorMessage: String?
    @State private var successCount: Int?
    
    struct ImageAssignment: Identifiable {
        let id = UUID()
        let image: DiskImage
        var scsiID: Int
        var imageIndex: Int
        var label: String
        var include: Bool = true
        
        var previewName: String {
            var name = "\(image.deviceType.scsiPrefix)\(scsiID)_\(imageIndex)"
            if !label.isEmpty { name += "_\(label)" }
            name += ".hda"
            return name
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Batch Rename for ZuluSCSI",
                subtitle: "Assign SCSI IDs and slots to all images",
                icon: "pencil.and.list.clipboard",
                onClose: { dismiss() }
            )
            
            Divider()
            
            // Table
            List {
                ForEach($assignments) { $assignment in
                    HStack(spacing: 12) {
                        Toggle("", isOn: $assignment.include)
                            .labelsHidden()
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignment.image.filename)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(assignment.previewName)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(minWidth: 200, alignment: .leading)
                        
                        Picker("ID", selection: $assignment.scsiID) {
                            ForEach(0...6, id: \.self) { id in
                                Text("\(id)").tag(id)
                            }
                        }
                        .frame(width: 70)
                        
                        Stepper("Slot \(assignment.imageIndex)", value: $assignment.imageIndex, in: 0...99)
                            .frame(width: 120)
                        
                        TextField("Label", text: $assignment.label)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { from, to in
                    assignments.move(fromOffsets: from, toOffset: to)
                    reindex()
                }
            }
            .frame(minHeight: 200)
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Button("All to ID 1") {
                    for i in assignments.indices {
                        assignments[i].scsiID = 1
                        assignments[i].imageIndex = i
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Sequential IDs") {
                    for i in assignments.indices {
                        assignments[i].scsiID = min(i, 6)
                        assignments[i].imageIndex = 0
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                if let count = successCount {
                    Label("Renamed \(count) image(s)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                Text("\(assignments.filter(\.include).count) of \(assignments.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Rename All") { renameAll() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(assignments.filter(\.include).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 750, idealWidth: 800, minHeight: 520, idealHeight: 560)
        .onAppear { buildAssignments() }
        .onExitCommand { dismiss() }
    }
    
    private func buildAssignments() {
        assignments = appState.images.enumerated().map { i, image in
            ImageAssignment(
                image: image,
                scsiID: image.scsiID ?? 1,
                imageIndex: image.imageIndex ?? i,
                label: image.label ?? ""
            )
        }
    }
    
    private func reindex() {
        for i in assignments.indices {
            assignments[i].imageIndex = i
        }
    }
    
    private func renameAll() {
        let selected = assignments.filter(\.include)
        errorMessage = nil
        successCount = nil
        
        // Check for naming conflicts
        let names = selected.map(\.previewName)
        let uniqueNames = Set(names)
        if names.count != uniqueNames.count {
            errorMessage = "Duplicate filenames! Adjust IDs or slots."
            return
        }
        
        var renamed = 0
        for assignment in selected {
            do {
                _ = try appState.fileService.renameImage(
                    assignment.image,
                    scsiID: assignment.scsiID,
                    imageIndex: assignment.imageIndex,
                    label: assignment.label.isEmpty ? nil : assignment.label
                )
                renamed += 1
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
                break
            }
        }
        
        appState.refreshImages()
        appState.statusMessage = "Renamed \(renamed) image(s)"
        successCount = renamed
        
        if errorMessage == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
        }
    }
}
