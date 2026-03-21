import SwiftUI

/// Verify EMAX II disk structure and integrity
struct VerifyDiskView: View {
    @Environment(\.dismiss) var dismiss
    
    let image: DiskImage
    
    @State private var isVerifying = true
    @State private var result: ImageValidator.ValidationResult?
    @State private var errorMessage: String?
    @State private var showDetailedErrors = false
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Verify Disk",
                subtitle: "industry-standard format Compatibility Check",
                icon: "checkmark.seal",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if isVerifying {
                verifyingView
            } else if let result = result {
                resultView(result)
            } else if let error = errorMessage {
                errorView(error)
            }
        }
        .frame(width: 600, height: 500)
        .onAppear { runVerification() }
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Verifying
    
    private var verifyingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Verifying disk structure...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Result
    
    private func resultView(_ result: ImageValidator.ValidationResult) -> some View {
        VStack(spacing: 0) {
            // Status header
            VStack(spacing: 16) {
                Image(systemName: result.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(result.isValid ? .green : .orange)
                
                Text(result.isValid ? "Disk Valid!" : "Issues Detected")
                    .font(.title2.bold())
                
                Text(result.isValid ? "This disk passes all industry-standard format compatibility checks" : "Some checks failed - see details below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Checks list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(result.checks.enumerated()), id: \.offset) { index, check in
                        checkRow(check)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            // Error details section
            if !result.isValid && showDetailedErrors {
                errorDetailsSection(result)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if !result.isValid {
                    Button(showDetailedErrors ? "Hide Error Codes" : "Show Error Codes (E001-E020)") {
                        if !showDetailedErrors && result.errors == nil {
                            // Fetch detailed errors
                            Task {
                                await revalidateDetailed()
                            }
                        }
                        showDetailedErrors.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                
                if result.isValid {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([image.url])
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
    
    private func checkRow(_ check: ImageValidator.ValidationResult.Check) -> some View {
        HStack(spacing: 12) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(check.passed ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(check.name)
                    .font(.headline)
                
                Text(check.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(check.passed ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - Error
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            
            VStack(spacing: 8) {
                Text("Verification Failed")
                    .font(.title2.bold())
                
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
            .padding(.bottom, 20)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func runVerification() {
        Task {
            defer {
                Task { @MainActor in
                    isVerifying = false
                }
            }
            
            // Small delay for UI
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            do {
                let validationResult = try await ImageValidator.validate(imageURL: image.url, detailed: false)
                await MainActor.run {
                    self.result = validationResult
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Verification error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func revalidateDetailed() async {
        do {
            let validationResult = try await ImageValidator.validate(imageURL: image.url, detailed: true)
            await MainActor.run {
                self.result = validationResult
            }
        } catch {
            // Ignore errors, keep existing result
        }
    }
    
    // MARK: - Error Details
    
    @ViewBuilder
    private func errorDetailsSection(_ result: ImageValidator.ValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Codes")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.top, 16)
            
            if let errors = result.errors, !errors.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(errors, id: \.code) { error in
                            errorCodeCard(error)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 300)
            } else if result.errorCount > 0 {
                ProgressView("Loading error details...")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            } else {
                Text("No detailed error information available")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func errorCodeCard(_ error: ImageValidator.ValidationResult.ValidationError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(error.code)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.orange)
                
                Text(error.title)
                    .font(.headline)
            }
            
            Text(error.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let context = error.context {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(context)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            
            if let hint = error.repairHint {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.caption)
                    Text(hint)
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }
            
            if let offset = error.offset {
                HStack(spacing: 6) {
                    Image(systemName: "location")
                        .font(.caption)
                    Text("Offset: \(offset)")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }
}

/// Preview
#if DEBUG
struct VerifyDiskView_Previews: PreviewProvider {
    static var previews: some View {
        VerifyDiskView(image: DiskImage.example)
    }
}
#endif
