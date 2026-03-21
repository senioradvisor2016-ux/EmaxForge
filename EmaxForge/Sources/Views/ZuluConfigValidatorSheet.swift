import SwiftUI
import UniformTypeIdentifiers

// MARK: - Validation Models

enum ValidationSeverity {
    case ok, warning, error, suggestion

    var icon: String {
        switch self {
        case .ok:         return "checkmark.circle.fill"
        case .warning:    return "exclamationmark.triangle.fill"
        case .error:      return "xmark.circle.fill"
        case .suggestion: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok:         return Theme.success
        case .warning:    return Theme.amber
        case .error:      return Theme.danger
        case .suggestion: return Theme.cyan
        }
    }
}

struct ValidationIssue: Identifiable {
    let id = UUID()
    let severity: ValidationSeverity
    let message: String
    let fix: String?
    let lineNumber: Int?
    let key: String?
}

// MARK: - Validator

private enum ZuluConfigValidator {
    static func validate(text: String) -> [ValidationIssue] {
        var issues = [ValidationIssue]()
        let lines = text.components(separatedBy: "\n")

        var hasSCSI = false
        var hasType = false
        var hasBlockSize = false
        var hasSelectionDelay = false
        var hasStartupDelay = false
        var hasEnableParity = false
        var parsedEntries: [(key: String, value: String, line: Int)] = []

        for (lineIdx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix(";") && !trimmed.hasPrefix("#") else { continue }

            if trimmed.hasPrefix("[SCSI") || trimmed.hasPrefix("[scsi") {
                hasSCSI = true
                continue
            }
            if trimmed.hasPrefix("[") { continue }

            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else {
                if !trimmed.contains("=") && !trimmed.hasPrefix("[") {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "Line \(lineIdx+1): Unexpected syntax '\(trimmed)'",
                        fix: nil, lineNumber: lineIdx+1, key: nil
                    ))
                }
                continue
            }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            parsedEntries.append((key: key, value: value, line: lineIdx+1))

            switch key.lowercased() {
            case "type":
                hasType = true
                if value == "0" {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "Line \(lineIdx+1): Type=0 may cause issues. Consider omitting it or using a specific type.",
                        fix: "Remove the Type= line or set it to the appropriate drive type.",
                        lineNumber: lineIdx+1, key: "Type"
                    ))
                }
            case "blocksize":
                hasBlockSize = true
                if let bsize = Int(value), bsize != 512 {
                    issues.append(ValidationIssue(
                        severity: .error,
                        message: "Line \(lineIdx+1): BlockSize=\(value) is invalid. EMAX II requires BlockSize=512.",
                        fix: "Set BlockSize = 512",
                        lineNumber: lineIdx+1, key: "BlockSize"
                    ))
                }
            case "selectiondelay":
                hasSelectionDelay = true
                if let delay = Int(value), delay < 255 {
                    issues.append(ValidationIssue(
                        severity: .suggestion,
                        message: "SelectionDelay=\(value) — value 255 works best for EMAX II.",
                        fix: "Set SelectionDelay = 255",
                        lineNumber: lineIdx+1, key: "SelectionDelay"
                    ))
                }
            case "startupdelay":
                hasStartupDelay = true
            case "enableparity":
                hasEnableParity = true
            default: break
            }
        }

        // Global checks
        if !hasSCSI {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing [SCSI] section header",
                fix: "Add [SCSI] before your drive configuration entries",
                lineNumber: nil, key: nil
            ))
        }

        if parsedEntries.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Config file is empty",
                fix: "Generate a default config from the ZuluSCSI Config editor",
                lineNumber: nil, key: nil
            ))
        }

        // Suggestions
        if !hasSelectionDelay {
            issues.append(ValidationIssue(
                severity: .suggestion,
                message: "Missing SelectionDelay — recommended value is 255 for EMAX II",
                fix: "Add: SelectionDelay = 255",
                lineNumber: nil, key: "SelectionDelay"
            ))
        }
        if !hasEnableParity {
            issues.append(ValidationIssue(
                severity: .suggestion,
                message: "Missing EnableParity — recommended: EnableParity = 1",
                fix: "Add: EnableParity = 1",
                lineNumber: nil, key: "EnableParity"
            ))
        }
        if !hasStartupDelay {
            issues.append(ValidationIssue(
                severity: .suggestion,
                message: "Missing StartupDelay — if ZuluSCSI isn't detected on boot, try StartupDelay = 2000",
                fix: "Add: StartupDelay = 2000",
                lineNumber: nil, key: "StartupDelay"
            ))
        }

        if issues.isEmpty {
            issues.append(ValidationIssue(
                severity: .ok,
                message: "Configuration looks valid — no issues found",
                fix: nil, lineNumber: nil, key: nil
            ))
        }

        return issues
    }

    static func applyFixes(to text: String, issues: [ValidationIssue]) -> String {
        var lines = text.components(separatedBy: "\n")

        for issue in issues {
            guard let fix = issue.fix, let key = issue.key else { continue }

            // If issue has a line number, fix in-place
            if let lineIdx = issue.lineNumber.map({ $0 - 1 }),
               lineIdx < lines.count, lines[lineIdx].contains(key) {
                let fixValue = fix.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                lines[lineIdx] = "\(key) = \(fixValue)"
            } else if issue.lineNumber == nil {
                // Append at end of [SCSI] section
                let fixLine = fix.trimmingCharacters(in: .whitespaces)
                if !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == fixLine }) {
                    lines.append(fixLine)
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Main View

struct ZuluConfigValidatorSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedFile: URL?
    @State private var configText = ""
    @State private var issues: [ValidationIssue] = []
    @State private var showPreview = false
    @State private var previewText = ""
    @State private var saveSuccess = false
    @State private var errorMessage: String?

    private var hasErrors: Bool { issues.contains(where: { $0.severity == .error }) }
    private var hasWarnings: Bool { issues.contains(where: { $0.severity == .warning }) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "ZuluSCSI Config Validator",
                subtitle: "Validate and fix your zuluscsi.ini",
                icon: "checkmark.shield",
                onClose: { dismiss() }
            )

            Divider()

            HSplitView {
                // Left: file + editor
                leftPanel

                // Right: validation results
                rightPanel
            }

            Divider()

            footerButtons
        }
        .frame(width: 800, height: 600)
        .onExitCommand { dismiss() }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File picker
            HStack(spacing: 10) {
                if let url = selectedFile {
                    Image(systemName: "doc.text").foregroundStyle(Theme.accent)
                    Text(url.lastPathComponent).font(Theme.Typography.body).lineLimit(1)
                    Spacer()
                    Button("Change…") { pickFile() }.buttonStyle(.bordered)
                } else {
                    Button("Select zuluscsi.ini…") { pickFile() }.buttonStyle(.bordered)
                    Spacer()
                    if let volume = appState.selectedVolume {
                        Button("Load from Volume") { loadFromVolume(volume) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(10)
            .background(Theme.bgSurface)

            Divider()

            // Config text editor
            TextEditor(text: $configText)
                .font(.system(size: 12, design: .monospaced))
                .padding(4)
                .onChange(of: configText) { _, _ in
                    if !configText.isEmpty { issues = ZuluConfigValidator.validate(text: configText) }
                }

            Divider()

            // Quick validate button
            Button {
                issues = ZuluConfigValidator.validate(text: configText)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Validate")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(10)
            .disabled(configText.isEmpty)
        }
        .frame(minWidth: 320)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("VALIDATION RESULTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                if !issues.isEmpty {
                    summaryBadges
                }
            }
            .padding(12)
            .background(Theme.bgSurface)

            Divider()

            if issues.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Click Validate to check your config")
                        .font(.headline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(issues) { issue in
                            issueRow(issue)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 340)
    }

    private var summaryBadges: some View {
        HStack(spacing: 6) {
            let errors = issues.filter { $0.severity == .error }.count
            let warnings = issues.filter { $0.severity == .warning }.count
            let suggestions = issues.filter { $0.severity == .suggestion }.count

            if errors > 0 { badge("\(errors)", Theme.danger) }
            if warnings > 0 { badge("\(warnings)", Theme.amber) }
            if suggestions > 0 { badge("\(suggestions)", Theme.cyan) }
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color)
            .cornerRadius(8)
    }

    private func issueRow(_ issue: ValidationIssue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: issue.severity.icon)
                    .foregroundStyle(issue.severity.color)
                    .font(.system(size: 13))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(issue.message)
                        .font(Theme.Typography.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let fix = issue.fix {
                        Text("Fix: \(fix)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(issue.severity.color.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            if saveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    Text("Saved!").font(Theme.Typography.caption).foregroundStyle(Theme.success)
                }
            }
            if let err = errorMessage {
                Text(err).font(Theme.Typography.caption).foregroundStyle(Theme.danger).lineLimit(1)
            }
            if !issues.isEmpty && issues.contains(where: { $0.fix != nil }) {
                Button("Auto-Fix All") { autoFix() }
                    .buttonStyle(.bordered)
            }
            if !configText.isEmpty {
                Button("Save to File") { saveToFile() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ini")].compactMap { $0 }
        panel.nameFieldStringValue = "zuluscsi.ini"
        if panel.runModal() == .OK, let url = panel.url {
            selectedFile = url
            loadFile(url)
        }
    }

    private func loadFile(_ url: URL) {
        do {
            configText = try String(contentsOf: url, encoding: .utf8)
            issues = ZuluConfigValidator.validate(text: configText)
        } catch {
            errorMessage = "Could not read file: \(error.localizedDescription)"
        }
    }

    private func loadFromVolume(_ volume: MountedVolume) {
        let iniURL = volume.url.appendingPathComponent("zuluscsi.ini")
        if FileManager.default.fileExists(atPath: iniURL.path) {
            selectedFile = iniURL
            loadFile(iniURL)
        } else {
            let configService = ZuluSCSIConfigService()
            configText = configService.generateConfig(for: appState.currentDevice, images: appState.images)
            issues = ZuluConfigValidator.validate(text: configText)
        }
    }

    private func autoFix() {
        let fixableIssues = issues.filter { $0.fix != nil }
        configText = ZuluConfigValidator.applyFixes(to: configText, issues: fixableIssues)
        issues = ZuluConfigValidator.validate(text: configText)
    }

    private func saveToFile() {
        if let url = selectedFile {
            do {
                try configText.write(to: url, atomically: true, encoding: .utf8)
                saveSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveSuccess = false }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "zuluscsi.ini"
            panel.allowedContentTypes = [UTType(filenameExtension: "ini")].compactMap { $0 }
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try configText.write(to: url, atomically: true, encoding: .utf8)
                    selectedFile = url
                    saveSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveSuccess = false }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
