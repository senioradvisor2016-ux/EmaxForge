import SwiftUI

/// Sheet for verifying disk image integrity
struct VerifyDiskSheet: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    
    @State private var result: DiskVerifier.VerifyResult?
    @State private var isVerifying = false
    @State private var showDetails: Set<String> = []
    
    private var passCount: Int { result?.checks.filter(\.passed).count ?? 0 }
    private var failCount: Int { result?.checks.filter({ !$0.passed }).count ?? 0 }
    private var warnCount: Int { result?.warnings.count ?? 0 }
    
    private var overallStatus: String {
        guard let r = result else { return "Unknown" }
        if !r.passed { return "Failed" }
        if !r.warnings.isEmpty { return "Passed with warnings" }
        return "Passed"
    }
    
    private var statusColor: Color {
        guard let r = result else { return .secondary }
        if !r.passed { return .red }
        if !r.warnings.isEmpty { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundColor(Theme.accent)
                    Text("Disk Verification")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Text(imageURL.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Content
            if isVerifying {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Verifying disk image...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if result == nil {
                VStack(spacing: 16) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Ready to verify")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = result {
                // Results
                VStack(spacing: 0) {
                    // Summary
                    HStack {
                        Label("\(passCount) passed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        if warnCount > 0 {
                            Label("\(warnCount) warnings", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                        if failCount > 0 {
                            Label("\(failCount) errors", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        Spacer()
                        Text(overallStatus)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                    }
                    .padding()
                    .background(statusColor.opacity(0.1))
                    
                    Divider()
                    
                    // Results list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(result.checks, id: \.name) { check in
                                checkRow(check)
                                Divider()
                            }
                            
                            if !result.warnings.isEmpty {
                                Section {
                                    ForEach(result.warnings, id: \.self) { warning in
                                        HStack(spacing: 12) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .frame(width: 24)
                                            Text(warning)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding()
                                        Divider()
                                    }
                                } header: {
                                    HStack {
                                        Text("Warnings")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                if result != nil {
                    Button("Copy Report") {
                        copyReport()
                    }
                }
                
                Spacer()
                
                if isVerifying {
                    // No buttons while verifying
                } else if result == nil {
                    Button("Verify") {
                        runVerification()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Re-verify") {
                        runVerification()
                    }
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            runVerification()
        }
    }
    
    // MARK: - Check Row
    
    @ViewBuilder
    private func checkRow(_ check: DiskVerifier.Check) -> some View {
        Button {
            if showDetails.contains(check.name) {
                showDetails.remove(check.name)
            } else {
                showDetails.insert(check.name)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(check.passed ? .green : .red)
                        .frame(width: 24)
                    
                    Text(check.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: showDetails.contains(check.name) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if showDetails.contains(check.name) {
                    Text(check.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                        .padding(.top, 2)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func runVerification() {
        isVerifying = true
        result = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let r = DiskVerifier.verify(imageURL: imageURL)
            DispatchQueue.main.async {
                self.result = r
                self.isVerifying = false
            }
        }
    }
    
    private func copyReport() {
        guard let result = result else { return }
        var report = "# Disk Verification Report\n\n"
        report += "**File:** \(imageURL.lastPathComponent)\n"
        report += "**Status:** \(overallStatus)\n\n"
        report += "## Checks\n\n"
        
        for check in result.checks {
            let icon = check.passed ? "✅" : "❌"
            report += "\(icon) **\(check.name):** \(check.detail)\n"
        }
        
        if !result.warnings.isEmpty {
            report += "\n## Warnings\n\n"
            for warning in result.warnings {
                report += "⚠️ \(warning)\n"
            }
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }
}
