import SwiftUI

/// Performance optimizations for smooth UI
extension View {
    /// Disable animations for this view (useful for preventing flicker)
    func disableAnimations() -> some View {
        self.transaction { transaction in
            transaction.animation = nil
        }
    }
    
    /// Batch state updates to prevent multiple re-renders
    func batchedUpdates<T: Hashable>(_ value: T) -> some View {
        self.id(value)
    }
    
    /// Use drawing group for complex views (better performance)
    func optimizedRendering() -> some View {
        self.drawingGroup()
    }
}

/// Debounced state for preventing rapid updates
@propertyWrapper
struct Debounced<T: Equatable>: DynamicProperty {
    @State private var value: T
    @State private var debounceTask: Task<Void, Never>?
    
    private let delay: TimeInterval
    
    var wrappedValue: T {
        get { value }
        nonmutating set {
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        value = newValue
                    }
                }
            }
        }
    }
    
    init(wrappedValue: T, delay: TimeInterval = 0.15) {
        self._value = State(initialValue: wrappedValue)
        self.delay = delay
    }
}

/// Throttled state for limiting update frequency
@propertyWrapper
struct Throttled<T: Equatable>: DynamicProperty {
    @State private var value: T
    @State private var lastUpdate: Date = Date()
    @State private var pendingValue: T?
    
    private let interval: TimeInterval
    
    var wrappedValue: T {
        get { value }
        nonmutating set {
            let now = Date()
            if now.timeIntervalSince(lastUpdate) >= interval {
                value = newValue
                lastUpdate = now
                pendingValue = nil
            } else {
                pendingValue = newValue
                // Schedule update
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    if let pending = pendingValue {
                        value = pending
                        pendingValue = nil
                        lastUpdate = Date()
                    }
                }
            }
        }
    }
    
    init(wrappedValue: T, interval: TimeInterval = 0.1) {
        self._value = State(initialValue: wrappedValue)
        self.interval = interval
    }
}
