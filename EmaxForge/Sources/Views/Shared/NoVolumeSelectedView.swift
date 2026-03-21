import SwiftUI

/// Fallback view shown when a sheet requires a volume but none is selected
struct NoVolumeSelectedView: View {
    @Environment(\.dismiss) var dismiss
    let action: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.orange.gradient)
            
            Text("No Volume Selected")
                .font(.title2.bold())
            
            Text("Please select a ZuluSCSI volume first to \(action).")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(width: 450, height: 350)
    }
}
