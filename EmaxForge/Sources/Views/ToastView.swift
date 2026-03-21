import SwiftUI

/// Toast notification component
struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    let undoAction: (() -> Void)?
    @Binding var isPresented: Bool
    
    @State private var dismissTask: Task<Void, Never>?
    
    init(
        message: String,
        icon: String,
        color: Color,
        undoAction: (() -> Void)? = nil,
        isPresented: Binding<Bool>
    ) {
        self.message = message
        self.icon = icon
        self.color = color
        self.undoAction = undoAction
        self._isPresented = isPresented
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
            
            Spacer()
            
            if let undo = undoAction {
                Button("Undo") {
                    undo()
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            }
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .foregroundStyle(.white)
        .frame(maxWidth: 320)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 3 seconds (or 5 if undo available)
            let delay = undoAction != nil ? 5.0 : 3.0
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await MainActor.run {
                    if !Task.isCancelled {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3)) {
            isPresented = false
        }
    }
}

/// Toast manager for displaying notifications
class ToastManager: ObservableObject {
    @Published var currentToast: ToastItem?
    
    struct ToastItem: Identifiable {
        let id = UUID()
        let message: String
        let icon: String
        let color: Color
        let undoAction: (() -> Void)?
    }
    
    func show(_ item: ToastItem) {
        currentToast = item
    }
    
    func show(message: String, icon: String, color: Color, undoAction: (() -> Void)? = nil) {
        show(ToastItem(message: message, icon: icon, color: color, undoAction: undoAction))
    }
    
    func dismiss() {
        currentToast = nil
    }
}

/// Environment key for ToastManager
private struct ToastManagerKey: EnvironmentKey {
    static let defaultValue: ToastManager? = nil
}

extension EnvironmentValues {
    var toastManager: ToastManager? {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

/// Toast container view modifier
struct ToastContainer: ViewModifier {
    @StateObject private var toastManager = ToastManager()
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .environment(\.toastManager, toastManager)
            
            if let toast = toastManager.currentToast {
                ToastView(
                    message: toast.message,
                    icon: toast.icon,
                    color: toast.color,
                    undoAction: toast.undoAction,
                    isPresented: Binding(
                        get: { toastManager.currentToast != nil },
                        set: { if !$0 { toastManager.dismiss() } }
                    )
                )
                .padding(16)
                .zIndex(1000)
            }
        }
    }
}

extension View {
    func toastContainer() -> some View {
        modifier(ToastContainer())
    }
}
