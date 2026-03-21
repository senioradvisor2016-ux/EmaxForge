import SwiftUI

// MARK: - Terminal Output Model

private struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let isCommand: Bool
    let isError: Bool
}

// MARK: - REPL Process Manager

@MainActor
private class REPLManager: ObservableObject {
    @Published var lines: [TerminalLine] = []
    @Published var isRunning = false
    @Published var isConnected = false

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    private let cliPaths = [
        "/usr/local/bin/cli-anything-emaxforge",
        "\(NSHomeDirectory())/bin/cli-anything-emaxforge",
        "\(NSHomeDirectory())/.local/bin/cli-anything-emaxforge"
    ]

    var cliPath: String? { cliPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) }

    func start() {
        guard let path = cliPath else {
            appendLine("Error: EmaxForge CLI not found. Install to /usr/local/bin/cli-anything-emaxforge", isError: true)
            appendLine("Entering offline mode — type 'help' for built-in commands.", isError: false)
            isConnected = false
            return
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["repl"]

        let inp = Pipe()
        let out = Pipe()
        let err = Pipe()
        p.standardInput = inp
        p.standardOutput = out
        p.standardError = err

        inputPipe = inp
        outputPipe = out
        errorPipe = err
        process = p

        do {
            try p.run()
            isConnected = true
            isRunning = true
            appendLine("Connected to EmaxForge CLI REPL — type 'help' for commands", isError: false)

            // Read stdout
            out.fileHandleForReading.readabilityHandler = { [weak self] fh in
                let data = fh.availableData
                if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    Task { @MainActor [weak self] in
                        self?.appendMultiline(text, isError: false)
                    }
                }
            }
            // Read stderr
            err.fileHandleForReading.readabilityHandler = { [weak self] fh in
                let data = fh.availableData
                if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    Task { @MainActor [weak self] in
                        self?.appendMultiline(text, isError: true)
                    }
                }
            }

            p.terminationHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isRunning = false
                    self?.isConnected = false
                    self?.appendLine("REPL process exited.", isError: false)
                }
            }
        } catch {
            appendLine("Failed to start REPL: \(error.localizedDescription)", isError: true)
        }
    }

    func send(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendLine("$ \(trimmed)", isCommand: true)

        if isConnected, let inp = inputPipe {
            let data = (trimmed + "\n").data(using: .utf8) ?? Data()
            inp.fileHandleForWriting.write(data)
        } else {
            // Offline built-in commands
            handleOfflineCommand(trimmed)
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        isConnected = false
    }

    func clear() { lines = [] }

    private func handleOfflineCommand(_ cmd: String) {
        switch cmd.lowercased() {
        case "help":
            appendLine("Available commands (offline mode):", isError: false)
            appendLine("  help           — Show this help", isError: false)
            appendLine("  clear          — Clear terminal", isError: false)
            appendLine("  version        — Show CLI version info", isError: false)
            appendLine("  analyze-fat    — Analyze FAT structure", isError: false)
            appendLine("  list-catalog   — List disk catalog", isError: false)
            appendLine("  validate-zulu  — Validate ZuluSCSI config", isError: false)
        case "version":
            appendLine("EmaxForge CLI — offline mode (CLI binary not found)", isError: false)
        case "clear":
            lines = []
        default:
            appendLine("Command not found: \(cmd). Install CLI or type 'help'.", isError: true)
        }
    }

    private func appendLine(_ text: String, isCommand: Bool = false, isError: Bool = false) {
        let entry = TerminalLine(text: text, isCommand: isCommand, isError: isError)
        lines.append(entry)
    }

    private func appendMultiline(_ text: String, isError: Bool) {
        let lineTexts = text.components(separatedBy: "\n")
        for line in lineTexts where !line.isEmpty {
            appendLine(line, isError: isError)
        }
    }
}

// MARK: - Main View

struct TerminalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var repl = REPLManager()

    @State private var commandInput = ""
    @State private var history: [String] = []
    @State private var historyIndex = -1
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Terminal (REPL)",
                subtitle: "Interactive EmaxForge command line",
                icon: "terminal",
                onClose: {
                    repl.stop()
                    dismiss()
                }
            )

            Divider()

            // Connection status bar
            statusBar

            Divider()

            // Output area
            outputArea

            Divider()

            // Input area
            inputArea
        }
        .frame(width: 720, height: 560)
        .background(Color.black)
        .onAppear { repl.start(); inputFocused = true }
        .onDisappear { repl.stop() }
        .onExitCommand { repl.stop(); dismiss() }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(repl.isConnected ? Theme.success : .orange)
                .frame(width: 8, height: 8)
            Text(repl.isConnected ? "Connected to CLI REPL" : "Offline mode")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                repl.clear()
            } label: {
                Text("Clear")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)

            if repl.isRunning {
                Button {
                    repl.stop()
                } label: {
                    Text("Stop REPL")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    repl.start()
                } label: {
                    Text("Restart")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Output Area

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(repl.lines) { line in
                        Text(line.text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(lineColor(line))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(10)
            }
            .background(Color.black)
            .onChange(of: repl.lines.count) { _, _ in
                if let last = repl.lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func lineColor(_ line: TerminalLine) -> Color {
        if line.isCommand { return Theme.accent }
        if line.isError   { return Theme.danger }
        return Color(white: 0.85)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)

            TextField("Enter command…", text: $commandInput)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit { submitCommand() }
                .onKeyPress(.upArrow) { navigateHistory(-1); return .handled }
                .onKeyPress(.downArrow) { navigateHistory(1); return .handled }

            Button("Run") { submitCommand() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Actions

    private func submitCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        if cmd.lowercased() == "clear" {
            repl.clear()
        } else {
            repl.send(cmd)
        }
        history.insert(cmd, at: 0)
        if history.count > 100 { history.removeLast() }
        historyIndex = -1
        commandInput = ""
        inputFocused = true
    }

    private func navigateHistory(_ direction: Int) {
        guard !history.isEmpty else { return }
        historyIndex = max(-1, min(history.count - 1, historyIndex + direction))
        if historyIndex == -1 {
            commandInput = ""
        } else {
            commandInput = history[historyIndex]
        }
    }
}
