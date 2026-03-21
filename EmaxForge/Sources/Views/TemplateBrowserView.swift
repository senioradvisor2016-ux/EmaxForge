import SwiftUI

// MARK: - Main View

struct TemplateBrowserView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var templates: [BankTemplateService.Template] = []
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @State private var selectedTemplate: BankTemplateService.Template?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    enum ViewMode: String, CaseIterable {
        case grid = "square.grid.2x2"
        case list = "list.bullet"
    }

    private var filtered: [BankTemplateService.Template] {
        guard !searchText.isEmpty else { return templates }
        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Template Browser",
                subtitle: "Browse built-in bank templates",
                icon: "square.grid.3x3.square",
                onClose: { dismiss() }
            )

            Divider()

            // Search + view toggle bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search templates…", text: $searchText)
                    .textFieldStyle(.plain)
                Spacer()
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Theme.bgSurface)

            Divider()

            if isLoading {
                loadingView
            } else if filtered.isEmpty {
                emptyView
            } else {
                Group {
                    if viewMode == .grid { gridView }
                    else { listView }
                }
            }

            Divider()

            footerButtons
        }
        .frame(width: 720, height: 560)
        .onAppear { loadTemplates() }
        .onExitCommand { dismiss() }
        .sheet(isPresented: $showCreateSheet, onDismiss: { loadTemplates() }) {
            TemplateCreatorSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 12)], spacing: 12) {
                ForEach(filtered) { template in
                    templateCard(template)
                }
            }
            .padding()
        }
    }

    private func templateCard(_ template: BankTemplateService.Template) -> some View {
        let isSelected = selectedTemplate?.id == template.id
        return Button {
            selectedTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("\(template.presets) presets")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(template.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(template.description)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(height: 110)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.accent.opacity(0.15) : Theme.bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - List View

    private var listView: some View {
        List(filtered, selection: Binding(
            get: { selectedTemplate?.id },
            set: { id in selectedTemplate = filtered.first(where: { $0.id == id }) }
        )) { template in
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name).font(.system(size: 13, weight: .semibold))
                    Text(template.description).font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(template.presets) presets")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .tag(template.id)
        }
        .listStyle(.plain)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.1)
            Text("Loading templates…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 36)).foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "No templates available" : "No templates match '\(searchText)'")
                .font(.headline).foregroundStyle(.secondary)
            if let err = errorMessage {
                Text(err).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Button("Create Custom Template") { showCreateSheet = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            if !filtered.isEmpty {
                Text("\(filtered.count) template\(filtered.count == 1 ? "" : "s")")
                    .font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Button {
                showCreateSheet = true
            } label: {
                Label("Create Template…", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding()
    }

    // MARK: - Data

    private func loadTemplates() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let loaded = try await BankTemplateService.listTemplates()
                await MainActor.run {
                    templates = loaded
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
