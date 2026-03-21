import SwiftUI

/// Consistent sheet header — EMULOTION style
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accent)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.5)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(Theme.bgSurface)
    }
}
