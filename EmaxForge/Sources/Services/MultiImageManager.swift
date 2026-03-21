import Foundation

/// Manages multi-image slots for ZuluSCSI (HD0_0, HD0_1, HD0_2, etc)
class MultiImageManager {
    
    /// Grouped images by SCSI ID and slot index
    struct ImageSlot: Identifiable, Hashable {
        let id = UUID()
        let scsiID: Int
        let slotIndex: Int
        let image: DiskImage
        var isActive: Bool = false  // Currently selected slot (if detectable)
        
        var displayName: String {
            if let label = image.label, !label.isEmpty {
                return "\(label) (Slot \(slotIndex))"
            }
            return "Slot \(slotIndex)"
        }
        
        // Hashable conformance
        static func == (lhs: ImageSlot, rhs: ImageSlot) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    struct SlotGroup: Identifiable, Hashable {
        let id: Int  // SCSI ID
        let scsiID: Int
        var slots: [ImageSlot]
        
        var displayName: String { "SCSI ID \(scsiID)" }
        var hasMultipleSlots: Bool { slots.count > 1 }
        var totalSize: Int64 {
            slots.reduce(0) { $0 + $1.image.fileSize }
        }
        
        // Hashable conformance
        static func == (lhs: SlotGroup, rhs: SlotGroup) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    // MARK: - Grouping
    
    /// Group images by SCSI ID, sorted by slot index
    static func groupImagesBySlot(_ images: [DiskImage]) -> [SlotGroup] {
        var groups: [Int: [ImageSlot]] = [:]
        
        for image in images {
            guard let scsiID = image.scsiID else { continue }
            let slotIndex = image.imageIndex ?? 0
            
            let slot = ImageSlot(
                scsiID: scsiID,
                slotIndex: slotIndex,
                image: image
            )
            
            if groups[scsiID] != nil {
                groups[scsiID]?.append(slot)
            } else {
                groups[scsiID] = [slot]
            }
        }
        
        // Sort slots within each group
        for (scsiID, _) in groups {
            groups[scsiID]?.sort { $0.slotIndex < $1.slotIndex }
        }
        
        // Build SlotGroups
        let slotGroups = groups.map { (scsiID, slots) in
            SlotGroup(id: scsiID, scsiID: scsiID, slots: slots)
        }
        
        return slotGroups.sorted { $0.scsiID < $1.scsiID }
    }
    
    /// Check if a volume has multi-image setups
    static func hasMultiImageSetup(_ images: [DiskImage]) -> Bool {
        let groups = groupImagesBySlot(images)
        return groups.contains { $0.hasMultipleSlots }
    }
    
    // MARK: - Slot Operations
    
    /// Create a new empty slot for a given SCSI ID
    static func createNewSlot(scsiID: Int, slotIndex: Int, sizeMB: Int, at volumeURL: URL, device: DeviceType) throws -> URL {
        let filename = "\(device.scsiPrefix)\(scsiID)_\(slotIndex).hda"
        let imageURL = volumeURL.appendingPathComponent(filename)
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: imageURL.path) {
            throw NSError(domain: "MultiImageManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Slot \(slotIndex) already exists for SCSI ID \(scsiID)"
            ])
        }
        
        // Create empty image
        try ImageCreator.createBootableImage(at: imageURL, sizeMB: sizeMB)
        
        return imageURL
    }
    
    /// Duplicate an existing slot to a new index
    static func duplicateSlot(sourceImage: DiskImage, targetSlotIndex: Int, at volumeURL: URL) throws -> URL {
        guard let scsiID = sourceImage.scsiID else {
            throw NSError(domain: "MultiImageManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Source image has no SCSI ID"
            ])
        }
        
        let filename = "\(sourceImage.deviceType.scsiPrefix)\(scsiID)_\(targetSlotIndex).hda"
        let targetURL = volumeURL.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: targetURL.path) {
            throw NSError(domain: "MultiImageManager", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Target slot already exists"
            ])
        }
        
        try FileManager.default.copyItem(at: sourceImage.url, to: targetURL)
        
        return targetURL
    }
    
    /// Rename a slot (change slot index)
    static func renameSlot(image: DiskImage, newSlotIndex: Int, at volumeURL: URL) throws -> URL {
        guard let scsiID = image.scsiID else {
            throw NSError(domain: "MultiImageManager", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Image has no SCSI ID"
            ])
        }
        
        let labelSuffix = image.label.map { "_\($0)" } ?? ""
        let filename = "\(image.deviceType.scsiPrefix)\(scsiID)_\(newSlotIndex)\(labelSuffix).hda"
        let targetURL = volumeURL.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: targetURL.path) {
            throw NSError(domain: "MultiImageManager", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Target slot already exists"
            ])
        }
        
        try FileManager.default.moveItem(at: image.url, to: targetURL)
        
        return targetURL
    }
    
    /// Delete a slot
    static func deleteSlot(image: DiskImage) throws {
        try FileManager.default.removeItem(at: image.url)
    }
    
    // MARK: - Active Slot Detection
    
    /// Try to detect which slot is currently "active" (ZuluSCSI-specific)
    /// This is difficult without ZuluSCSI hardware access.
    /// For now, we assume slot 0 is active if it exists, otherwise the first slot.
    static func detectActiveSlot(in group: SlotGroup) -> ImageSlot? {
        // Prefer slot 0
        if let slot0 = group.slots.first(where: { $0.slotIndex == 0 }) {
            return slot0
        }
        // Fallback to first slot
        return group.slots.first
    }
    
    // MARK: - Info
    
    /// Generate human-readable summary of multi-image setup
    static func generateSummary(for groups: [SlotGroup]) -> String {
        var lines: [String] = []
        
        for group in groups where group.hasMultipleSlots {
            let slotIndices = group.slots.map { String($0.slotIndex) }.joined(separator: ", ")
            lines.append("SCSI ID \(group.scsiID): \(group.slots.count) slots (\(slotIndices))")
        }
        
        if lines.isEmpty {
            return "No multi-image setups detected."
        }
        
        return lines.joined(separator: "\n")
    }
}
