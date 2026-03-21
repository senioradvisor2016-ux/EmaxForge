import SwiftUI

/// Shimmer effect for skeleton loading
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.1),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 200
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Skeleton loader for image list items
struct ImageListSkeleton: View {
    let count: Int
    
    init(count: Int = 5) {
        self.count = count
    }
    
    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            HStack(spacing: Theme.Spacing.md) {
                // Icon skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 40, height: 40)
                    .shimmer()
                
                // Text skeletons
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: CGFloat.random(in: 150...250), height: 16)
                        .shimmer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: CGFloat.random(in: 100...180), height: 12)
                        .shimmer()
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
