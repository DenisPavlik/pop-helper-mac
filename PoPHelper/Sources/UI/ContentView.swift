import SwiftUI
import AppKit

enum SidebarItem: Hashable {
    case all
    case category(String)
}

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var selection: SidebarItem? = .all
    @State private var searchText = ""
    @State private var showResetConfirm = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            Group {
                if let error = app.loadError {
                    errorView(error)
                } else {
                    detailView
                }
            }
            .frame(minWidth: 520, minHeight: 480)
            .toolbar { toolbarContent }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: L10n.searchPlaceholder.text(for: app.language))
        .confirmationDialog(
            L10n.resetConfirmTitle.text(for: app.language),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.resetConfirmButton.text(for: app.language), role: .destructive) {
                app.resetToDefaults()
            }
            Button(L10n.cancel.text(for: app.language), role: .cancel) {}
        } message: {
            Text(L10n.resetConfirmMessage.text(for: app.language))
        }
    }

    // MARK: Sidebar

    private var categories: [String] { CategoryMeta.sorted(app.categories) }

    private var sidebar: some View {
        List(selection: $selection) {
            Label {
                HStack {
                    Text(L10n.allTweaks.text(for: app.language))
                    Spacer()
                    countBadge(on: appliedCount(in: nil), total: app.states.count)
                }
            } icon: {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(.secondary)
            }
            .tag(SidebarItem.all)

            Section(L10n.categoriesHeader.text(for: app.language)) {
                ForEach(categories, id: \.self) { category in
                    Label {
                        HStack {
                            Text(L10n.categoryName(category).text(for: app.language))
                            Spacer()
                            countBadge(on: appliedCount(in: category), total: app.states(in: category).count)
                        }
                    } icon: {
                        Image(systemName: CategoryMeta.icon(category))
                            .foregroundStyle(CategoryMeta.tint(category))
                    }
                    .tag(SidebarItem.category(category))
                }
            }
        }
        .safeAreaInset(edge: .bottom) { sidebarFooter }
    }

    private func countBadge(on: Int, total: Int) -> some View {
        Text(on > 0 ? "\(on)/\(total)" : "\(total)")
            .font(.caption2)
            .foregroundStyle(on > 0 ? Color.green : .secondary)
            .monospacedDigit()
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Prophesy of Pendor 3.9.5").font(.caption.weight(.medium))
            Text(app.modFolderPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(app.modFolderPath)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: Detail

    private var visibleStates: [TweakViewState] {
        let base: [TweakViewState]
        if searchText.isEmpty {
            switch selection {
            case .category(let c): base = app.states(in: c)
            default: base = app.states
            }
        } else {
            // Search spans every category.
            let q = searchText.lowercased()
            base = app.states.filter {
                $0.tweak.name.text(for: app.language).lowercased().contains(q)
                    || $0.tweak.description.text(for: app.language).lowercased().contains(q)
            }
        }
        return base
    }

    private var detailTitle: String {
        if !searchText.isEmpty { return L10n.searchPlaceholder.text(for: app.language) }
        switch selection {
        case .category(let c): return L10n.categoryName(c).text(for: app.language)
        default: return L10n.allTweaks.text(for: app.language)
        }
    }

    private var detailView: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()
            if visibleStates.isEmpty {
                ContentUnavailableView(
                    L10n.noMatches.text(for: app.language),
                    systemImage: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleStates) { state in
                            TweakCard(state: binding(for: state.id))
                        }
                    }
                    .padding(16)
                }
            }
            Divider()
            actionBar
        }
    }

    private var detailHeader: some View {
        let total = visibleStates.count
        let on = visibleStates.filter {
            if case .applied = $0.status { return true } else { return false }
        }.count
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(detailTitle).font(.title2.weight(.semibold))
                Text(String(format: L10n.summary.text(for: app.language), on, total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if let message = app.lastActionMessage {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(app.dirtyCount > 0
                     ? String(format: L10n.pendingSummary.text(for: app.language), app.dirtyCount)
                     : L10n.noPending.text(for: app.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if app.dirtyCount > 0 {
                Button(L10n.discard.text(for: app.language)) { app.discardChanges() }
            }
            Button {
                app.applyChanges()
            } label: {
                Text("\(L10n.applyChanges.text(for: app.language)) (\(app.dirtyCount))")
            }
            .keyboardShortcut("s")
            .buttonStyle(.borderedProminent)
            .disabled(app.dirtyCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("", selection: $app.language) {
                Text("Укр").tag(AppLanguage.ukrainian)
                Text("Eng").tag(AppLanguage.english)
            }
            .pickerStyle(.segmented)
            .frame(width: 104)

            Menu {
                Button(L10n.chooseFolder.text(for: app.language)) { chooseFolder() }
                Divider()
                Button(L10n.openBackupsFolder.text(for: app.language)) {
                    NSWorkspace.shared.open(app.manager.backupsRoot)
                }
                if let latest = app.manager.listBackups().first {
                    Button("\(L10n.restoreLatestBackup.text(for: app.language)) (\(latest.lastPathComponent))") {
                        restore(latest)
                    }
                }
                Divider()
                Button(L10n.resetToDefaults.text(for: app.language), role: .destructive) {
                    showResetConfirm = true
                }
                .disabled(!app.canResetToDefaults)
            } label: {
                Label(L10n.settings.text(for: app.language), systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: Error / helpers

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(L10n.chooseFolder.text(for: app.language)) { chooseFolder() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func appliedCount(in category: String?) -> Int {
        let states = category.map { app.states(in: $0) } ?? app.states
        return states.filter { if case .applied = $0.status { return true } else { return false } }.count
    }

    private func binding(for id: String) -> Binding<TweakViewState> {
        Binding(
            get: { app.states.first(where: { $0.id == id }) ?? app.states[0] },
            set: { newValue in
                if let i = app.states.firstIndex(where: { $0.id == id }) {
                    app.states[i] = newValue
                }
            })
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(fileURLWithPath: app.modFolderPath)
        if panel.runModal() == .OK, let url = panel.url {
            app.setModFolder(url)
        }
    }

    private func restore(_ backup: URL) {
        do {
            try app.manager.restore(backup: backup)
            app.lastActionMessage = String(
                format: L10n.restoredMessage.text(for: app.language), backup.lastPathComponent)
            app.reload()
        } catch {
            app.lastActionMessage = error.localizedDescription
        }
    }
}
