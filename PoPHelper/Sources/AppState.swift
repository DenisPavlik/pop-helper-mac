import Foundation
import SwiftUI

/// Per-tweak UI state: what the user wants vs what's on disk.
struct TweakViewState: Identifiable {
    let tweak: Tweak
    var status: TweakStatus
    var desiredEnabled: Bool
    /// Param values to use when (re)applying.
    var desiredValues: [String: Int]

    var id: String { tweak.id }

    var isDirty: Bool {
        switch status {
        case .notApplied:
            return desiredEnabled
        case .applied(let current):
            if !desiredEnabled { return true }
            return tweak.params.contains { desiredValues[$0.key] != current[$0.key] }
        case .conflict:
            return false
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published var states: [TweakViewState] = []
    @Published var loadError: String?
    @Published var lastActionMessage: String?
    @Published var modFolderPath: String

    let manager: ModManager
    private var database: TweakDatabase?

    init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage")
        language = AppLanguage(rawValue: stored ?? "uk") ?? .ukrainian
        manager = ModManager()
        modFolderPath = manager.modFolder.path
        reload()
    }

    var categories: [String] {
        var seen: [String] = []
        for s in states where !seen.contains(s.tweak.category) {
            seen.append(s.tweak.category)
        }
        return seen
    }

    func states(in category: String) -> [TweakViewState] {
        states.filter { $0.tweak.category == category }
    }

    var dirtyCount: Int { states.filter(\.isDirty).count }

    func setModFolder(_ url: URL) {
        manager.setModFolder(url)
        modFolderPath = url.path
        reload()
    }

    func reload() {
        loadError = nil
        do {
            let db = try database ?? TweakDatabase.load()
            database = db
            guard manager.modFolderExists else {
                states = []
                loadError = L10n.modFolderMissing.text(for: language) + "\n" + manager.modFolder.path
                return
            }
            // First time we see this folder, snapshot its full state as a safety net.
            _ = try? manager.ensureInitialBackup()
            let fileNames = Set(db.tweaks.flatMap { $0.operations.map(\.file) })
            let files = try manager.readFiles(named: fileNames)
            states = db.tweaks.map { tweak in
                let status = TweakEngine.status(of: tweak, files: files)
                var values = Dictionary(uniqueKeysWithValues: tweak.params.map { ($0.key, $0.defaultValue) })
                if case .applied(let current) = status {
                    values.merge(current) { _, applied in applied }
                }
                return TweakViewState(
                    tweak: tweak,
                    status: status,
                    desiredEnabled: { if case .applied = status { return true } else { return false } }(),
                    desiredValues: values)
            }
        } catch {
            states = []
            loadError = error.localizedDescription
        }
    }

    /// Applies every dirty tweak: backs up the touched files once, edits in memory, writes to disk, reloads.
    func applyChanges() {
        lastActionMessage = nil
        let dirty = states.filter(\.isDirty)
        guard !dirty.isEmpty else { return }
        do {
            let fileNames = Set(dirty.flatMap { $0.tweak.operations.map(\.file) })
            var files = try manager.readFiles(named: fileNames)
            for state in dirty {
                // A value change on an applied tweak = revert to pristine, then re-apply.
                if case .applied = state.status {
                    try TweakEngine.revert(state.tweak, in: &files)
                }
                if state.desiredEnabled {
                    try TweakEngine.apply(state.tweak, values: state.desiredValues, to: &files)
                }
            }
            let backupDir = try manager.backup(files: fileNames)
            try manager.write(files: files)
            lastActionMessage = String(
                format: L10n.appliedMessage.text(for: language),
                dirty.count, backupDir.lastPathComponent)
            reload()
        } catch {
            lastActionMessage = error.localizedDescription
            reload()
        }
    }

    func discardChanges() {
        reload()
    }

    var canResetToDefaults: Bool {
        manager.modFolderExists && manager.canResetToDefaults
    }

    /// Restores every module file to vanilla 3.9.5, undoing all tweaks (known or not).
    func resetToDefaults() {
        lastActionMessage = nil
        do {
            switch try manager.resetToDefaults() {
            case .restored(let count, let safety):
                lastActionMessage = String(
                    format: L10n.resetDoneMessage.text(for: language),
                    count, safety.lastPathComponent)
            case .unavailable:
                lastActionMessage = L10n.resetUnavailable.text(for: language)
            }
            reload()
        } catch {
            lastActionMessage = error.localizedDescription
            reload()
        }
    }
}
