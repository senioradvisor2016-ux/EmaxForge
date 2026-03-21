import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var volumes: [MountedVolume] = []
    @State private var showingFormatVolumeSheet = false
    @State private var volumeToFormat: MountedVolume?
    
    var body: some View {
        List(selection: $appState.selectedVolume) {
            Section {
                let removable = volumes.filter(\.isRemovable)
                if removable.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.orange.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "sdcard")
                                    .foregroundStyle(.orange.opacity(0.5))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No drives detected")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("Insert SD card or USB drive")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(removable) { volume in
                        VolumeRow(volume: volume)
                            .tag(volume)
                            .contextMenu {
                                Button("Show in Finder") {
                                    NSWorkspace.shared.open(volume.url)
                                }
                                
                                Divider()
                                
                                Button("Format Volume…", role: .destructive) {
                                    volumeToFormat = volume
                                    showingFormatVolumeSheet = true
                                }
                                
                                Divider()
                                
                                Button("Eject \(volume.name)") {
                                    appState.ejectVolume(volume)
                                }
                            }
                    }
                }
            } header: {
                Label("Removable Drives", systemImage: "sdcard")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            
            if !volumes.filter({ !$0.isRemovable }).isEmpty {
                Section {
                    ForEach(volumes.filter { !$0.isRemovable }) { volume in
                        VolumeRow(volume: volume)
                            .tag(volume)
                            .contextMenu {
                                Button("Show in Finder") {
                                    NSWorkspace.shared.open(volume.url)
                                }
                                
                                Divider()
                                
                                Button("Format Volume…", role: .destructive) {
                                    volumeToFormat = volume
                                    showingFormatVolumeSheet = true
                                }
                                
                                Divider()
                                
                                Button("Eject \(volume.name)") {
                                    appState.ejectVolume(volume)
                                }
                            }
                    }
                } header: {
                    Label("Other Volumes", systemImage: "externaldrive")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            
            if let selected = appState.selectedVolume, !volumes.contains(selected) {
                Section {
                    VolumeRow(volume: selected)
                        .tag(selected)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.open(selected.url)
                            }
                            
                            // Don't show Format for local folders (not physical volumes)
                            // Only show if it looks like a removable device path
                            if selected.url.path.hasPrefix("/Volumes/") {
                                Divider()
                                
                                Button("Format Volume…", role: .destructive) {
                                    volumeToFormat = selected
                                    showingFormatVolumeSheet = true
                                }
                            }
                        }
                } header: {
                    Label("Local Folder", systemImage: "folder")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            
            // Recent activity
            if !appState.recentActivity.isEmpty {
                Section {
                    ForEach(appState.recentActivity.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.type.icon)
                                .foregroundStyle(item.type.color)
                                .font(.caption)
                            Text(item.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Label("Recent Activity", systemImage: "clock")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear { refreshVolumes() }
        .onChange(of: appState.selectedVolume) { _, _ in
            appState.refreshImages()
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            refreshVolumes()
        }
        .sheet(isPresented: $showingFormatVolumeSheet) {
            if let vol = volumeToFormat {
                FormatVolumeSheet(volume: vol)
            }
        }
    }
    
    private func refreshVolumes() {
        volumes = MountedVolume.scanMounted()
    }
}

struct VolumeRow: View {
    let volume: MountedVolume
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(volume.isRemovable ? .orange.opacity(0.15) : .blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: volume.isRemovable ? "sdcard.fill" : "folder.fill")
                    .foregroundStyle(volume.isRemovable ? .orange : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(volume.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if volume.totalSize > 0 {
                    HStack(spacing: 6) {
                        ProgressView(value: volume.usagePercent)
                            .tint(volume.usagePercent > 0.9 ? .red : .accentColor)
                            .scaleEffect(y: 0.7)
                        Text(volume.formattedFree)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}
