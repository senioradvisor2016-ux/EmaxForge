import SwiftUI

/// Command palette (Cmd+K) for quick actions
struct CommandPalette: View {
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var appState: AppState
    
    var commands: [Command] {
        [
            Command(title: "Open Folder", icon: "folder", shortcut: "⌘O", action: .openFolder),
            Command(title: "Refresh", icon: "arrow.clockwise", shortcut: "⌘R", action: .commandPaletteRefresh),
            Command(title: "Create Bootable Disk", icon: "wand.and.stars", shortcut: "⌘⇧B", action: .bootableDiskWizard),
            Command(title: "Batch Rename", icon: "pencil.and.list.clipboard", shortcut: "⌘⇧R", action: .batchRename),
            Command(title: "Backup & Restore", icon: "externaldrive.badge.timemachine", shortcut: "⌘⌥S", action: .backupRestore),
            Command(title: "Knowledge Base", icon: "book", shortcut: "⌘⇧K", action: .showKnowledgeBase),
        ]
    }
    
    var filteredCommands: [Command] {
        if query.isEmpty {
            return commands
        }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.shortcut.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Type a command...", text: $query)
                            .textFieldStyle(.plain)
                            .focused($isFocused)
                            .font(Theme.Typography.body)
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                    
                    // Command list
                    if filteredCommands.isEmpty {
                        Text("No commands found")
                            .foregroundStyle(.secondary)
                            .padding(Theme.Spacing.xl)
                    } else {
                        List(filteredCommands) { command in
                            CommandRow(command: command)
                                .onTapGesture {
                                    executeCommand(command)
                                }
                        }
                        .listStyle(.plain)
                        .frame(height: min(300, CGFloat(filteredCommands.count) * 50))
                    }
                }
                .frame(width: 500)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .applyShadow(Theme.Elevation.modal)
                )
                .padding(Theme.Spacing.xl)
            }
            .transition(.opacity)
            .onAppear {
                isFocused = true
            }
            .onKeyPress(.escape) {
                isPresented = false
                return .handled
            }
        }
    }
    
    private func executeCommand(_ command: Command) {
        if command.action == .commandPaletteRefresh {
            // Special handling for refresh
            appState.refreshImages()
        } else {
            NotificationCenter.default.post(name: command.action, object: nil)
        }
        isPresented = false
    }
}

struct Command: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let shortcut: String
    let action: Notification.Name
}

struct CommandRow: View {
    let command: Command
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: command.icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            
            Text(command.title)
                .font(Theme.Typography.body)
            
            Spacer()
            
            Text(command.shortcut)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.quaternary)
                )
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// Command palette uses existing notification names from EmaxForgeApp
