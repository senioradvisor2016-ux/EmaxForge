import SwiftUI

/// Browse disk catalog entries (OS + banks)
struct CatalogBrowserView: View {
    @Environment(\.dismiss) var dismiss
    
    let image: DiskImage
    
    @State private var isLoading = true
    @State private var summary: CatalogService.CatalogSummary?
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var filteredEntries: [CatalogService.CatalogEntry] {
        guard let summary = summary else { return [] }
        
        if searchText.isEmpty {
            return summary.entries.filter { !$0.isOS }  // Hide OS from list
        }
        
        return summary.entries.filter { entry in
            !entry.isOS && entry.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Catalog Browser",
                subtitle: image.filename,
                icon: "list.bullet.rectangle",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let summary = summary {
                contentView(summary)
            }
        }
        .frame(width: 800, height: 600)
        .onAppear { loadCatalog() }
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Reading catalog...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Error Loading Catalog")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Content
    
    private func contentView(_ summary: CatalogService.CatalogSummary) -> some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader(summary)
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search banks...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Catalog list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredEntries) { entry in
                        catalogRow(entry, clusterSize: summary.clusterSize)
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredEntries.count) of \(summary.bankCount) banks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
            .padding()
        }
    }
    
    private func statsHeader(_ summary: CatalogService.CatalogSummary) -> some View {
        HStack(spacing: 24) {
            statCard(
                icon: "doc.text",
                label: "Total Entries",
                value: "\(summary.totalEntries)"
            )
            
            statCard(
                icon: "checkmark.circle",
                label: "Active",
                value: "\(summary.activeEntries)"
            )
            
            statCard(
                icon: "music.note.list",
                label: "Banks",
                value: "\(summary.bankCount)"
            )
            
            if let os = summary.osEntry {
                statCard(
                    icon: "crown",
                    label: "OS",
                    value: os.name,
                    subtitle: "\(os.cluster) · \(String(format: "%.2f MB", os.sizeMB))"
                )
            }
            
            statCard(
                icon: "square.grid.3x3",
                label: "Cluster Size",
                value: formatBytes(summary.clusterSize)
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private func statCard(icon: String, label: String, value: String, subtitle: String? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .lineLimit(1)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func catalogRow(_ entry: CatalogService.CatalogEntry, clusterSize: Int) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            // Name + info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label("\(entry.cluster)", systemImage: "square.grid.3x3")
                    Label(String(format: "%.2f MB", entry.sizeMB), systemImage: "internaldrive")
                    
                    if entry.presetCount > 0 {
                        Label("\(entry.presetCount) presets", systemImage: "music.mic")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Index
            Text("#\(entry.index)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .contentShape(Rectangle())
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024) KB"
        } else {
            return "\(bytes / (1024 * 1024)) MB"
        }
    }
    
    // MARK: - Load Data
    
    private func loadCatalog() {
        Task {
            do {
                let catalogSummary = try await CatalogService.getSummary(imageURL: image.url)
                await MainActor.run {
                    self.summary = catalogSummary
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
