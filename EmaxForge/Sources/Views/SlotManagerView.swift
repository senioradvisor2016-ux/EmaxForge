import SwiftUI
import UniformTypeIdentifiers

/// Visual manager for multi-image slots (HD0_0, HD0_1, etc)
struct SlotManagerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let volumeURL: URL
    let volumeName: String
    
    @State private var slotGroups: [MultiImageManager.SlotGroup] = []
    @State private var selectedGroup: MultiImageManager.SlotGroup?
    @State private var selectedSlot: MultiImageManager.ImageSlot?
    @State private var showNewSlotSheet = false
    @State private var showDuplicateSheet = false
    @State private var newSlotSizeMB = 239  // ZIP 250 (default)
    @State private var statusMessage: String?
    @State private var showDeleteConfirm = false
    @State private var slotToDelete: MultiImageManager.ImageSlot?
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            if slotGroups.isEmpty {
                emptyState
            } else {
                HSplitView {
                    groupList
                        .frame(minWidth: 200, idealWidth: 250)
                    
                    if let group = selectedGroup {
                        slotGridView(group: group)
                    } else {
                        placeholderView
                    }
                }
            }
            
            if let msg = statusMessage {
                Divider()
                statusBar(msg)
            }
        }
        .frame(width: 900, height: 600)
        .onAppear { refreshSlots() }
        .onExitCommand { dismiss() }
        .sheet(isPresented: $showNewSlotSheet) {
            newSlotSheet
        }
        .sheet(isPresented: $showDuplicateSheet) {
            duplicateSlotSheet
        }
        .alert("Delete Slot?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let slot = slotToDelete {
                Text("Delete \(slot.image.filename)? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Multi-Image Slot Manager")
                    .font(.headline)
                Text(volumeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                refreshSlots()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(.bar)
    }
    
    // MARK: - Group List
    
    private var groupList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SCSI IDs")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            
            List(slotGroups, selection: $selectedGroup) { group in
                GroupRow(group: group)
                    .tag(group)
            }
            .listStyle(.sidebar)
        }
    }
    
    // MARK: - Slot Grid
    
    private func slotGridView(group: MultiImageManager.SlotGroup) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(group.slots.count) Slot\(group.slots.count == 1 ? "" : "s")")
                    .font(.headline)
                
                Spacer()
                
                if group.hasMultipleSlots {
                    Text("Switch slots with ZuluSCSI button")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    showNewSlotSheet = true
                } label: {
                    Label("New Slot", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
            .padding()
            .background(Theme.bgCard.opacity(0.3))
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
                ], spacing: 16) {
                    ForEach(group.slots) { slot in
                        SlotCard(
                            slot: slot,
                            isSelected: selectedSlot?.id == slot.id,
                            onSelect: { selectedSlot = slot },
                            onDuplicate: {
                                selectedSlot = slot
                                showDuplicateSheet = true
                            },
                            onDelete: {
                                slotToDelete = slot
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Empty & Placeholder
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No multi-image slots detected")
                .font(.title3)
            
            Text("Images with names like HD10_0.hda, HD10_1.hda enable slot switching on ZuluSCSI.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Select a SCSI ID")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - New Slot Sheet
    
    private var newSlotSheet: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "plus.square.dashed")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("Create New Slot")
                    .font(.headline)
                Spacer()
            }
            
            if let group = selectedGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SCSI ID: \(group.scsiID)")
                        .font(.subheadline.bold())
                    
                    let nextSlot = (group.slots.map { $0.slotIndex }.max() ?? -1) + 1
                    Text("Next available slot: \(nextSlot)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image Size")
                            .font(.subheadline.bold())
                        
                        Picker("Size", selection: $newSlotSizeMB) {
                            Text("96 MB").tag(96)
                            Text("239 MB").tag(239)
                            Text("481 MB").tag(481)
                            Text("633 MB").tag(633)
                            Text("962 MB").tag(962)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") { showNewSlotSheet = false }
                        .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button("Create") { createNewSlot() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 280)
    }
    
    // MARK: - Duplicate Sheet
    
    private var duplicateSlotSheet: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.doc")
                    .font(.title2)
                    .foregroundStyle(Theme.cyan)
                Text("Duplicate Slot")
                    .font(.headline)
                Spacer()
            }
            
            if let slot = selectedSlot, let group = selectedGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source: Slot \(slot.slotIndex)")
                        .font(.subheadline.bold())
                    
                    Text(slot.image.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    let nextSlot = (group.slots.map { $0.slotIndex }.max() ?? -1) + 1
                    Text("Will create: Slot \(nextSlot)")
                        .font(.caption)
                        .foregroundStyle(Theme.cyan)
                    
                    Divider()
                    
                    Text("This creates an exact copy at the next available slot index.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") { showDuplicateSheet = false }
                        .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button("Duplicate") { performDuplicate() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 260)
    }
    
    // MARK: - Status Bar
    
    private func statusBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text(message)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    // MARK: - Actions
    
    private func refreshSlots() {
        slotGroups = MultiImageManager.groupImagesBySlot(appState.images)
        
        // Auto-select first group with multiple slots
        if selectedGroup == nil {
            selectedGroup = slotGroups.first { $0.hasMultipleSlots } ?? slotGroups.first
        }
    }
    
    private func createNewSlot() {
        guard let group = selectedGroup else { return }
        
        let nextSlot = (group.slots.map { $0.slotIndex }.max() ?? -1) + 1
        
        do {
            let newURL = try MultiImageManager.createNewSlot(
                scsiID: group.scsiID,
                slotIndex: nextSlot,
                sizeMB: newSlotSizeMB,
                at: volumeURL,
                device: appState.currentDevice
            )
            
            statusMessage = "Created \(newURL.lastPathComponent)"
            appState.addActivity("Created slot \(nextSlot) for SCSI ID \(group.scsiID)", type: .success)
            showNewSlotSheet = false
            appState.refreshImages()
            refreshSlots()
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    private func performDuplicate() {
        guard let slot = selectedSlot, let group = selectedGroup else { return }
        
        let nextSlot = (group.slots.map { $0.slotIndex }.max() ?? -1) + 1
        
        do {
            let newURL = try MultiImageManager.duplicateSlot(
                sourceImage: slot.image,
                targetSlotIndex: nextSlot,
                at: volumeURL
            )
            
            statusMessage = "Duplicated to \(newURL.lastPathComponent)"
            appState.addActivity("Duplicated slot \(slot.slotIndex) → \(nextSlot)", type: .success)
            showDuplicateSheet = false
            appState.refreshImages()
            refreshSlots()
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    private func performDelete() {
        guard let slot = slotToDelete else { return }
        
        do {
            try MultiImageManager.deleteSlot(image: slot.image)
            statusMessage = "Deleted \(slot.image.filename)"
            appState.addActivity("Deleted slot \(slot.slotIndex)", type: .warning)
            slotToDelete = nil
            appState.refreshImages()
            refreshSlots()
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let group: MultiImageManager.SlotGroup
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(group.hasMultipleSlots ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.gray.gradient))
                    .frame(width: 32, height: 32)
                
                Text("ID\(group.scsiID)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("SCSI ID \(group.scsiID)")
                    .fontWeight(.medium)
                
                HStack(spacing: 6) {
                    Text("\(group.slots.count) slot\(group.slots.count == 1 ? "" : "s")")
                    if group.hasMultipleSlots {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Slot Card

struct SlotCard: View {
    let slot: MultiImageManager.ImageSlot
    let isSelected: Bool
    let onSelect: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 40, height: 40)
                    
                    Text("\(slot.slotIndex)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slot \(slot.slotIndex)")
                        .font(.headline)
                    
                    if let label = slot.image.label, !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if slot.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                InfoRow(icon: "internaldrive", text: slot.image.formattedSize)
                InfoRow(icon: "doc", text: slot.image.filename)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(Theme.cyan)
                
                Spacer()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(isSelected ? Theme.accent.opacity(0.1) : Theme.bgCard.opacity(0.5),
                   in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
