import SwiftUI

@main
struct EmaxForgeApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .toastContainer()
                .frame(minWidth: 1000, minHeight: 650)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Start auto-save
                    appState.autoSaveManager.startAutoSave(for: appState)
                }
                .onDisappear {
                    appState.autoSaveManager.stopAutoSave()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 750)
        .commands {
            // File menu
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o")
                
                Divider()
                
                Button("Import Banks…") {
                    NotificationCenter.default.post(name: .importBanks, object: nil)
                }
                .keyboardShortcut("i")
                
                Button("Convert Samples…") {
                    NotificationCenter.default.post(name: .convertSamples, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                
                Button("New Image…") {
                    NotificationCenter.default.post(name: .newImage, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            // View menu
            CommandGroup(after: .toolbar) {
                Button("Browse Banks") {
                    NotificationCenter.default.post(name: .browseBanks, object: nil)
                }
                .keyboardShortcut("b")
                
                Button("Knowledge Base") {
                    NotificationCenter.default.post(name: .showKnowledgeBase, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Command Palette…") {
                    NotificationCenter.default.post(name: .commandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("Refresh") {
                    appState.refreshImages()
                }
                .keyboardShortcut("r")
                
                Divider()
                
                Button("Search Images") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f")
            }
            
            // Edit menu
            CommandGroup(after: .pasteboard) {
                Button("Undo") {
                    appState.undo()
                }
                .keyboardShortcut("z")
                .disabled(!appState.canUndo)
                
                Button("Redo") {
                    appState.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!appState.canRedo)
                
                Divider()
                
                Button("Duplicate Image…") {
                    NotificationCenter.default.post(name: .duplicateImage, object: nil)
                }
                .keyboardShortcut("d")
                
                Button("Delete Image") {
                    NotificationCenter.default.post(name: .deleteImage, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
                
                Divider()
                
                Button("Eject Volume") {
                    NotificationCenter.default.post(name: .ejectVolume, object: nil)
                }
                .keyboardShortcut("e")
            }
            
            // Tools menu
            CommandMenu("Tools") {
                // Create
                Button("Create Bootable Disk…") {
                    NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                
                Button("Create Floppy Image…") {
                    NotificationCenter.default.post(name: .createFloppy, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Divider()
                
                // Format
                Button("Format Disk Image…") {
                    NotificationCenter.default.post(name: .formatDisk, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                
                Button("Format SD/USB Volume…") {
                    NotificationCenter.default.post(name: .formatVolume, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                
                Divider()
                
                // Manage
                Button("Batch Rename…") {
                    NotificationCenter.default.post(name: .batchRename, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button("Batch Convertor…") {
                    NotificationCenter.default.post(name: .batchConvertor, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                
                Button("Multi-Image Slots…") {
                    NotificationCenter.default.post(name: .slotManager, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("Backup & Restore…") {
                    NotificationCenter.default.post(name: .backupRestore, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                
                Divider()
                
                // Config
                Button("ZuluSCSI Config…") {
                    NotificationCenter.default.post(name: .zuluConfig, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                Button("Knowledge Base") {
                    NotificationCenter.default.post(name: .showKnowledgeBase, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                // Diagnostics
                Button("Analyze FAT Structure…") {
                    NotificationCenter.default.post(name: .analyzeFAT, object: nil)
                }

                Button("Validate ZuluSCSI Config…") {
                    NotificationCenter.default.post(name: .validateZuluConfig, object: nil)
                }

                Button("Scan Directory for Images…") {
                    NotificationCenter.default.post(name: .scanImages, object: nil)
                }

                Button("Raw Catalog Viewer…") {
                    NotificationCenter.default.post(name: .listCatalog, object: nil)
                }

                Button("Terminal (REPL)…") {
                    NotificationCenter.default.post(name: .showTerminal, object: nil)
                }
                .keyboardShortcut("`", modifiers: [.command, .option])

                Divider()

                // Templates
                Button("Create Bank Template…") {
                    NotificationCenter.default.post(name: .createTemplate, object: nil)
                }

                Button("Browse Templates…") {
                    NotificationCenter.default.post(name: .browseTemplates, object: nil)
                }

                Divider()

                // Import / Convert
                Button("Batch Import Banks…") {
                    NotificationCenter.default.post(name: .batchImportBanks, object: nil)
                }

                Button("HFE → IMG Converter…") {
                    NotificationCenter.default.post(name: .convertHFE, object: nil)
                }
            }
            
            // Help menu
            CommandGroup(replacing: .help) {
                Button("Take Interactive Tour…") {
                    NotificationCenter.default.post(name: .showOnboardingTour, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
                
                Button("Show Getting Started") {
                    NotificationCenter.default.post(name: .showGettingStarted, object: nil)
                }
                
                Divider()
                
                Button("Knowledge Base") {
                    NotificationCenter.default.post(name: .showKnowledgeBase, object: nil)
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App-wide notification names

extension Notification.Name {
    static let openFolder = Notification.Name("openFolder")
    static let importBanks = Notification.Name("importBanks")
    static let newImage = Notification.Name("newImage")
    static let browseBanks = Notification.Name("browseBanks")
    static let showKnowledgeBase = Notification.Name("showKnowledgeBase")
    static let ejectVolume = Notification.Name("ejectVolume")
    static let convertSamples = Notification.Name("convertSamples")
    static let bootableDiskWizard = Notification.Name("bootableDiskWizard")
    static let duplicateImage = Notification.Name("duplicateImage")
    static let deleteImage = Notification.Name("deleteImage")
    static let batchRename = Notification.Name("batchRename")
    static let batchConvertor = Notification.Name("batchConvertor")
    static let slotManager = Notification.Name("slotManager")
    static let backupRestore = Notification.Name("backupRestore")
    static let zuluConfig = Notification.Name("zuluConfig")
    static let focusSearch = Notification.Name("focusSearch")
    static let formatDisk = Notification.Name("formatDisk")
    static let formatVolume = Notification.Name("formatVolume")
    static let createFloppy = Notification.Name("createFloppy")
    static let commandPalette = Notification.Name("commandPalette")
    static let commandPaletteRefresh = Notification.Name("commandPaletteRefresh")
    static let showOnboardingTour = Notification.Name("showOnboardingTour")
    static let showGettingStarted = Notification.Name("showGettingStarted")
    static let showSuccess = Notification.Name("showSuccess")

    // New features (v0.6)
    static let analyzeFAT = Notification.Name("analyzeFAT")
    static let batchImportBanks = Notification.Name("batchImportBanks")
    static let convertHFE = Notification.Name("convertHFE")
    static let createTemplate = Notification.Name("createTemplate")
    static let listCatalog = Notification.Name("listCatalog")
    static let browseTemplates = Notification.Name("browseTemplates")
    static let showTerminal = Notification.Name("showTerminal")
    static let scanImages = Notification.Name("scanImages")
    static let validateZuluConfig = Notification.Name("validateZuluConfig")
}
