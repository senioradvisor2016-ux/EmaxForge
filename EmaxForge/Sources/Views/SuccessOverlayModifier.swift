import SwiftUI

/// UX-05: Success overlay animation after operations complete
struct SuccessOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Done!")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 10)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4), value: isPresented)
    }
}

extension View {
    func successOverlay(isPresented: Binding<Bool>) -> some View {
        modifier(SuccessOverlayModifier(isPresented: isPresented))
    }
}
