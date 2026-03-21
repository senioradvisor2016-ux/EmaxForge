import SwiftUI

/// AI Assistant chat panel — right sidebar for EMAX II help
struct AIAssistantView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = AIAssistantService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.3)
            
            if service.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
            
            Divider().opacity(0.3)
            inputBar
        }
        .background(Theme.bgDeep)
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 420)
        .task {
            await service.checkConnection()
            updateContext()
        }
        .onChange(of: appState.images) { _ in updateContext() }
        .onChange(of: appState.selectedVolume) { _ in updateContext() }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
            
            Text("EmaxForge AI")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            
            Spacer()
            
            connectionBadge
            
            if !service.messages.isEmpty {
                Button(action: { service.clearHistory() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear chat history")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.bgSurface)
    }
    
    private var connectionBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionColor)
                .frame(width: 6, height: 6)
            
            Text(connectionLabel)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }
    
    private var connectionColor: Color {
        switch service.connectionState {
        case .connected: return Theme.success
        case .connecting: return Theme.amber
        case .disconnected: return Theme.danger
        case .error: return Theme.danger
        }
    }
    
    private var connectionLabel: String {
        switch service.connectionState {
        case .connected: return "Ollama"
        case .connecting: return "Connecting…"
        case .disconnected: return "Offline"
        case .error(let msg): return msg
        }
    }
    
    // MARK: - Empty State with Suggestions
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 30)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent.opacity(0.6))
                
                Text("Ask me anything about\nyour EMAX II setup")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 8) {
                    suggestionChip("How do I set up ZuluSCSI?", icon: "sdcard")
                    suggestionChip("Why won't my EMAX II boot?", icon: "power")
                    suggestionChip("Explain disk formats", icon: "doc")
                    suggestionChip("Help with SCSI termination", icon: "link")
                    suggestionChip("What disk sizes should I use?", icon: "internaldrive")
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func suggestionChip(_ text: String, icon: String) -> some View {
        Button(action: {
            inputText = text
            Task { await sendCurrentMessage() }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 16)
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.accent.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Message List
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(service.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    
                    if service.isStreaming {
                        streamingIndicator
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
            }
            .onChange(of: service.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: service.currentStreamingText) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = service.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                messageContent(message)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isUser ? Theme.accent.opacity(0.2) : Theme.bgCard,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                message.isUser ? Theme.accent.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
                
                Text(timeString(message.timestamp))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
            
            if message.isAssistant { Spacer(minLength: 40) }
        }
    }
    
    @ViewBuilder
    private func messageContent(_ message: ChatMessage) -> some View {
        if message.isAssistant {
            formattedText(message.content)
        } else {
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Simple Markdown-lite Rendering
    
    private func formattedText(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = text.components(separatedBy: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                formattedLine(line)
            }
        }
        .textSelection(.enabled)
    }
    
    @ViewBuilder
    private func formattedLine(_ line: String) -> some View {
        if line.hasPrefix("```") {
            // Code block delimiter — skip rendering
            EmptyView()
        } else if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        } else if line.hasPrefix("- ") || line.hasPrefix("• ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
                Text(inlineFormat(String(line.dropFirst(2))))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
            }
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 4)
        } else {
            Text(inlineFormat(line))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
        }
    }
    
    /// Handles **bold** and `code` inline formatting via AttributedString
    private func inlineFormat(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Bold: **text**
        while let boldStart = result.characters.firstRange(of: "**") {
            let afterBold = result.characters[boldStart.upperBound...]
            if let boldEnd = afterBold.firstRange(of: "**") {
                let contentRange = boldStart.upperBound ..< boldEnd.lowerBound
                result[contentRange].font = .system(size: 13, weight: .bold)
                result.removeSubrange(boldEnd)
                result.removeSubrange(boldStart)
            } else {
                break
            }
        }
        
        // Inline code: `text`
        while let codeStart = result.characters.firstRange(of: "`") {
            let afterCode = result.characters[codeStart.upperBound...]
            if let codeEnd = afterCode.firstRange(of: "`") {
                let contentRange = codeStart.upperBound ..< codeEnd.lowerBound
                result[contentRange].font = .system(size: 12, weight: .medium, design: .monospaced)
                result[contentRange].foregroundColor = Theme.cyan
                result.removeSubrange(codeEnd)
                result.removeSubrange(codeStart)
            } else {
                break
            }
        }
        
        return result
    }
    
    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.accent.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .offset(y: streamingDotOffset(i))
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.15),
                        value: service.isStreaming
                    )
            }
            Spacer()
        }
        .padding(.leading, 16)
    }
    
    private func streamingDotOffset(_ index: Int) -> CGFloat {
        service.isStreaming ? -3 : 0
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about EMAX II, ZuluSCSI…", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .focused($isInputFocused)
                .onSubmit { Task { await sendCurrentMessage() } }
            
            Button(action: { Task { await sendCurrentMessage() } }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Theme.textTertiary
                            : Theme.accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || service.isStreaming)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.bgSurface)
    }
    
    // MARK: - Actions
    
    private func sendCurrentMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        await service.sendMessage(text)
    }
    
    private func updateContext() {
        service.volumePath = appState.selectedVolume?.url.path
        service.loadedImages = appState.images.map { img in
            (name: img.filename, size: img.fileSize, scsiID: img.scsiID ?? -1)
        }
        service.deviceType = appState.currentDevice.displayName
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
