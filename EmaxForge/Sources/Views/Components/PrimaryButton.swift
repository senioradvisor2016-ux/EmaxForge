import SwiftUI

/// Primary button with micro-interactions
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Immediate visual feedback without animation delay
            isPressed = true
            action()
            // Reset after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
            }
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(Theme.Typography.body)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accentGradient)
            )
            .applyShadow(Theme.Elevation.button)
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
