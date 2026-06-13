import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = app.loadError {
                errorView(error)
            } else {
                tweakList
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 520)
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prophesy of Pendor 3.9.5")
                    .font(.headline)
                Text(app.modFolderPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(L10n.chooseFolder.text(for: app.language)) { chooseFolder() }
            Picker("", selection: $app.language) {
                Text("Укр").tag(AppLanguage.ukrainian)
                Text("Eng").tag(AppLanguage.english)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
        }
        .padding(12)
    }

    private var tweakList: some View {
        List {
            ForEach(app.categories, id: \.self) { category in
                Section(L10n.categoryName(category).text(for: app.language)) {
                    ForEach(app.states(in: category)) { state in
                        TweakRow(state: binding(for: state.id))
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button(L10n.chooseFolder.text(for: app.language)) { chooseFolder() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack {
            Menu(L10n.backups.text(for: app.language)) {
                Button(L10n.openBackupsFolder.text(for: app.language)) {
                    NSWorkspace.shared.open(app.manager.backupsRoot)
                }
                if let latest = app.manager.listBackups().first {
                    Button("\(L10n.restoreLatestBackup.text(for: app.language)) (\(latest.lastPathComponent))") {
                        restore(latest)
                    }
                } else {
                    Text(L10n.noBackups.text(for: app.language))
                }
            }
            .fixedSize()
            if let message = app.lastActionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text(L10n.resetToDefaults.text(for: app.language))
            }
            .disabled(!app.canResetToDefaults)
            Spacer()
            if app.dirtyCount > 0 {
                Button(L10n.discard.text(for: app.language)) { app.discardChanges() }
            }
            Button("\(L10n.applyChanges.text(for: app.language)) (\(app.dirtyCount))") {
                app.applyChanges()
            }
            .keyboardShortcut("s")
            .buttonStyle(.borderedProminent)
            .disabled(app.dirtyCount == 0)
        }
        .padding(12)
    }

    private func binding(for id: String) -> Binding<TweakViewState> {
        Binding(
            get: { app.states.first(where: { $0.id == id })! },
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
