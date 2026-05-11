import Foundation

// MARK: - DiskRegionSnapshot

/// A snapshot of a disk byte range captured *before* a modification.
/// Used to restore the original bytes during undo.
struct DiskRegionSnapshot {
    let fileURL: URL
    let offset: UInt64
    let originalData: Data
}

// MARK: - DiskTransaction

/// An atomic, undoable disk change consisting of one or more region snapshots.
struct DiskTransaction {
    let id: UUID
    let timestamp: Date
    /// Human-readable label shown in Undo/Redo menu items (e.g. "Rename preset 'FOO'").
    let description: String
    /// Every disk region that will be (or was) overwritten.
    let snapshots: [DiskRegionSnapshot]
}

// MARK: - DiskTransactionManager

/// Global undo/redo manager for all disk write operations in EmaxForge.
///
/// Usage pattern:
/// ```swift
/// // 1. Before modifying disk, capture the regions you are about to change:
/// let tx = try DiskTransactionManager.shared.beginTransaction(
///     description: "Rename sample",
///     regions: [(url: imageURL, offset: paramOffset, length: 64)]
/// )
/// // 2. Perform the disk write via PresetWriteService / SampleParamWriteService / etc.
/// try SampleParamWriteService.renameSample(...)
/// // 3. Commit so the transaction is pushed onto the undo stack:
/// DiskTransactionManager.shared.commit(tx)
/// ```
///
/// Thread safety: all mutations must happen on the @MainActor.
@MainActor
final class DiskTransactionManager: ObservableObject {

    static let shared = DiskTransactionManager()
    private init() {}

    // MARK: - Published state

    @Published private(set) var undoStack: [DiskTransaction] = []
    @Published private(set) var redoStack: [DiskTransaction] = []

    // MARK: - Computed properties

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var undoDescription: String? { undoStack.last?.description }
    var redoDescription: String? { redoStack.last?.description }

    /// Maximum number of undoable transactions kept in memory.
    private let maxDepth = 20

    // MARK: - Transaction lifecycle

    /// Capture disk regions BEFORE making changes.
    /// Returns a `DiskTransaction` that should be passed to `commit(_:)` after the write succeeds.
    ///
    /// - Parameters:
    ///   - description: Short action description for the Undo menu item.
    ///   - regions: Array of (url, byteOffset, byteLength) tuples describing every region that will change.
    func beginTransaction(
        description: String,
        regions: [(url: URL, offset: UInt64, length: Int)]
    ) throws -> DiskTransaction {
        let snapshots = try regions.map { region -> DiskRegionSnapshot in
            let handle = try FileHandle(forReadingFrom: region.url)
            defer { handle.closeFile() }
            handle.seek(toFileOffset: region.offset)
            let data = handle.readData(ofLength: region.length)
            return DiskRegionSnapshot(
                fileURL: region.url,
                offset: region.offset,
                originalData: data
            )
        }
        return DiskTransaction(
            id: UUID(),
            timestamp: Date(),
            description: description,
            snapshots: snapshots
        )
    }

    /// Push a completed transaction onto the undo stack.
    /// Clears the redo stack (a new action invalidates redo history).
    func commit(_ transaction: DiskTransaction) {
        undoStack.append(transaction)
        if undoStack.count > maxDepth {
            undoStack.removeFirst(undoStack.count - maxDepth)
        }
        redoStack.removeAll()
    }

    // MARK: - Undo / Redo

    /// Restore all snapshots of the most recent transaction, then move it to the redo stack.
    func undo() throws {
        guard let transaction = undoStack.last else { return }

        // Capture current state for redo before overwriting
        let redoSnapshots = try transaction.snapshots.map { snap -> DiskRegionSnapshot in
            let handle = try FileHandle(forReadingFrom: snap.fileURL)
            defer { handle.closeFile() }
            handle.seek(toFileOffset: snap.offset)
            let current = handle.readData(ofLength: snap.originalData.count)
            return DiskRegionSnapshot(
                fileURL: snap.fileURL,
                offset: snap.offset,
                originalData: current
            )
        }

        // Write back original bytes
        for snap in transaction.snapshots {
            let handle = try FileHandle(forUpdating: snap.fileURL)
            defer { handle.synchronizeFile(); handle.closeFile() }
            handle.seek(toFileOffset: snap.offset)
            handle.write(snap.originalData)
        }

        // Move to redo stack
        let redoTransaction = DiskTransaction(
            id: UUID(),
            timestamp: Date(),
            description: transaction.description,
            snapshots: redoSnapshots
        )
        undoStack.removeLast()
        redoStack.append(redoTransaction)
    }

    /// Restore all snapshots of the most recently undone transaction, then move it back to undo.
    func redo() throws {
        guard let transaction = redoStack.last else { return }

        // Capture current state for undo before overwriting
        let undoSnapshots = try transaction.snapshots.map { snap -> DiskRegionSnapshot in
            let handle = try FileHandle(forReadingFrom: snap.fileURL)
            defer { handle.closeFile() }
            handle.seek(toFileOffset: snap.offset)
            let current = handle.readData(ofLength: snap.originalData.count)
            return DiskRegionSnapshot(
                fileURL: snap.fileURL,
                offset: snap.offset,
                originalData: current
            )
        }

        // Write back
        for snap in transaction.snapshots {
            let handle = try FileHandle(forUpdating: snap.fileURL)
            defer { handle.synchronizeFile(); handle.closeFile() }
            handle.seek(toFileOffset: snap.offset)
            handle.write(snap.originalData)
        }

        let undoTransaction = DiskTransaction(
            id: UUID(),
            timestamp: Date(),
            description: transaction.description,
            snapshots: undoSnapshots
        )
        redoStack.removeLast()
        undoStack.append(undoTransaction)
    }

    // MARK: - Lifecycle

    /// Clear both stacks — call when a different image is opened.
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
