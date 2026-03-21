import SwiftUI

/// Breadcrumb navigation bar (e.g., "Volumes > HD1.hda > Banks > Piano Soft")
struct BreadcrumbBar: View {
    @Binding var path: NavigationPath
    let rootTitle: String
    
    var body: some View {
        HStack(spacing: 4) {
            // Root
            breadcrumbButton(title: rootTitle, icon: "folder", isLast: path.isEmpty) {
                path.removeLast(path.count)
            }
            
            // Path items
            if !path.isEmpty {
                ForEach(0..<path.count, id: \.self) { index in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    // Extract title from path
                    if let dest = extractDestination(at: index) {
                        breadcrumbButton(
                            title: dest.title,
                            icon: dest.icon,
                            isLast: index == path.count - 1
                        ) {
                            // Pop to this level
                            let dropCount = path.count - index - 1
                            if dropCount > 0 {
                                path.removeLast(dropCount)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    private func breadcrumbButton(title: String, icon: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.callout)
                    .lineLimit(1)
            }
            .foregroundStyle(isLast ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isLast ? Theme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(isLast)
    }
    
    /// Extract NavigationDestination from path at index
    private func extractDestination(at index: Int) -> NavigationDestination? {
        // NavigationPath doesn't expose its contents directly
        // We need to use a workaround: codable representation
        // For now, return nil and we'll pass destinations explicitly
        return nil
    }
}

/// Alternative: Explicit breadcrumb with passed destinations
struct ExplicitBreadcrumbBar: View {
    let crumbs: [(title: String, icon: String)]
    let onNavigate: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(crumbs.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                let isLast = index == crumbs.count - 1
                Button {
                    onNavigate(index)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: crumbs[index].icon)
                            .font(.caption)
                        Text(crumbs[index].title)
                            .font(.callout)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isLast ? .primary : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isLast ? Theme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(isLast)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
