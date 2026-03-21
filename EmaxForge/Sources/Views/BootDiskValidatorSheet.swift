import SwiftUI

/// Sheet that runs BootDiskValidator and shows pass/fail with specific error messages.
/// Presented from ImageDetailView via the "Validate Boot" inspect action.
struct BootDiskValidatorSheet: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var result: BootDiskValidator.ValidationResult?
    @State private var isValidating = false

    private var statusColor: Color {
        guard let r = result else { return .secondary }
        return r.isBootable ? .green : .red
    }

    private var statusLabel: String {
        guard let r = result else { return "Not yet validated" }
        return r.isBootable ? "Bootable ✓" : "Not Bootable ✗"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "bolt.shield.fill")
                        .font(.title)
                        .foregroundColor(Theme.accent)
                    Text("Boot Disk Validator")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Text(imageURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Body
            if isValidating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Validating boot structure…")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if result == nil {
                VStack(spacing: 16) {
                    Image(systemName: "questionmark.shield")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Checks boot signature, FAT, OS data, and catalog flags")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            } else if let result = result {
                VStack(spacing: 0) {
                    // Summary banner
                    HStack {
                        Image(systemName: result.isBootable ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .font(.title3)
                            .foregroundColor(statusColor)
                        Text(statusLabel)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                        Spacer()
                    }
                    .padding()
                    .background(statusColor.opacity(0.12))

                    Divider()

                    // Checks list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(result.checks, id: \.name) { check in
                                checkRow(check)
                                Divider()
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if result != nil {
                    Button("Copy Report") { copyReport() }
                }
                Spacer()
                if isValidating {
                    // nothing
                } else if result == nil {
                    Button("Validate") { runValidation() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Re-validate") { runValidation() }
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 540, height: 420)
        .onAppear { runValidation() }
    }

    // MARK: - Check row

    private func checkRow(_ check: BootDiskValidator.Check) -> some View {
        HStack(spacing: 12) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(check.passed ? .green : .red)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.name)
                    .font(.headline)
                Text(check.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func runValidation() {
        isValidating = true
        result = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let r = BootDiskValidator.validate(imageURL: imageURL)
            DispatchQueue.main.async {
                self.result = r
                self.isValidating = false
            }
        }
    }

    private func copyReport() {
        guard let result = result else { return }
        var report = "# Boot Disk Validation Report\n\n"
        report += "**File:** \(imageURL.lastPathComponent)\n"
        report += "**Status:** \(statusLabel)\n\n"
        report += "## Checks\n\n"
        for check in result.checks {
            report += (check.passed ? "✅" : "❌") + " **\(check.name):** \(check.message)\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }
}
