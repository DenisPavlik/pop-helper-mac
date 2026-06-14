import Foundation

/// Locates the mod folder, reads/writes module files with byte-exact round-tripping,
/// and snapshots files into timestamped backups before any write.
final class ModManager {

    static let defaultModPath = NSString(
        string: "~/Library/Application Support/Steam/steamapps/common/MountBlade Warband/Modules/Prophesy of Pendor V3.9.5"
    ).expandingTildeInPath

    static let defaultBackupsRoot = URL(
        fileURLWithPath: NSString(string: "~/Library/Application Support/PoP Helper Mac/Backups").expandingTildeInPath)

    /// App-managed copy of the pristine (vanilla) module files, used by "Reset to Defaults".
    static let defaultPristineStore = URL(
        fileURLWithPath: NSString(string: "~/Library/Application Support/PoP Helper Mac/Pristine").expandingTildeInPath)

    private(set) var modFolder: URL
    let backupsRoot: URL
    let pristineStore: URL

    init(modFolder: URL,
         backupsRoot: URL = ModManager.defaultBackupsRoot,
         pristineStore: URL = ModManager.defaultPristineStore) {
        self.modFolder = modFolder
        self.backupsRoot = backupsRoot
        self.pristineStore = pristineStore
    }

    convenience init() {
        let stored = UserDefaults.standard.string(forKey: "modFolderPath") ?? Self.defaultModPath
        self.init(modFolder: URL(fileURLWithPath: stored))
    }

    func setModFolder(_ url: URL) {
        modFolder = url
        UserDefaults.standard.set(url.path, forKey: "modFolderPath")
    }

    var modFolderExists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: modFolder.path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: File IO
    // Module .txt files are read/written as ISO-Latin-1: every byte maps to exactly one
    // character and back, so untouched parts of a file round-trip byte-exactly even if
    // the file isn't valid UTF-8. All search patterns in the DB are plain ASCII.

    func read(file name: String) throws -> String {
        let url = modFolder.appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .isoLatin1) else {
            throw TweakEngineError.fileMissing(name)
        }
        return text
    }

    func readFiles(named names: some Sequence<String>) throws -> [String: String] {
        var result: [String: String] = [:]
        for name in Set(names) {
            result[name] = try read(file: name)
        }
        return result
    }

    func write(files: [String: String]) throws {
        for (name, content) in files {
            guard let data = content.data(using: .isoLatin1) else { continue }
            try data.write(to: modFolder.appendingPathComponent(name), options: .atomic)
        }
    }

    // MARK: Backups

    /// Copies the given module files into a new timestamped backup folder; returns its URL.
    @discardableResult
    func backup(files names: some Sequence<String>, label: String? = nil) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let folderName = formatter.string(from: Date()) + (label.map { " — \($0)" } ?? "")
        let dir = backupsRoot.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in Set(names) {
            let src = modFolder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: src.path) else { continue }
            try FileManager.default.copyItem(at: src, to: dir.appendingPathComponent(name))
        }
        return dir
    }

    /// Backs up every module file currently in the mod root.
    @discardableResult
    func backupAllModuleFiles(label: String? = nil) throws -> URL {
        try backup(files: moduleFileNames(in: modFolder), label: label)
    }

    /// On the first time the app sees a given mod folder, snapshots its full current
    /// state so the user can always return to "how it was before this app touched it".
    @discardableResult
    func ensureInitialBackup() throws -> URL? {
        guard modFolderExists else { return nil }
        let key = "initialBackupDone:" + modFolder.path
        if UserDefaults.standard.bool(forKey: key) { return nil }
        let dir = try backupAllModuleFiles(label: "initial snapshot")
        UserDefaults.standard.set(true, forKey: key)
        return dir
    }

    func listBackups() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: backupsRoot, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// The app's full snapshot of the mod as it was the first time PoP Helper saw it,
    /// made by `ensureInitialBackup()`. This is the user's REAL pre-tweak mod (including
    /// any third-party mini-mods), unlike the bare-vanilla `pristineStore`.
    func initialSnapshot() -> URL? {
        listBackups().first { $0.lastPathComponent.hasSuffix("initial snapshot") }
    }

    func restore(backup dir: URL) throws {
        try restoreFiles(from: dir)
    }

    /// Copies every module file (`*.txt` and `module.ini`) from `dir` over the live mod.
    private func restoreFiles(from dir: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        for src in files where isModuleFile(src) {
            let dst = modFolder.appendingPathComponent(src.lastPathComponent)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: src, to: dst)
        }
    }

    private func isModuleFile(_ url: URL) -> Bool {
        url.pathExtension == "txt" || url.lastPathComponent == "module.ini"
    }

    private func moduleFileNames(in dir: URL) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter(isModuleFile).map(\.lastPathComponent)
    }

    // MARK: Pristine baseline / Reset to Defaults

    var hasPristineBaseline: Bool {
        !moduleFileNames(in: pristineStore).isEmpty
    }

    /// Finds the pre-tweak backup the old Windows PoP Helper made: the subfolder of
    /// `_backupHelper/Backup Your Files/` that actually contains module files (e.g.
    /// `[Tweaks] 26.10.23 …`). Returns the newest such folder.
    func detectPoPHelperPristineBackup() -> URL? {
        let root = modFolder
            .appendingPathComponent("_backupHelper")
            .appendingPathComponent("Backup Your Files")
        let subs = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return subs
            .filter { $0.hasDirectoryPath && moduleFileNames(in: $0).contains("menus.txt") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
    }

    /// Whether a "Reset to Defaults" is possible (a baseline exists or can be imported).
    var canResetToDefaults: Bool {
        hasPristineBaseline || detectPoPHelperPristineBackup() != nil
    }

    /// Imports `source`'s module files into the app-managed pristine store (overwriting it).
    @discardableResult
    func importPristineBaseline(from source: URL) throws -> Int {
        if FileManager.default.fileExists(atPath: pristineStore.path) {
            try FileManager.default.removeItem(at: pristineStore)
        }
        try FileManager.default.createDirectory(at: pristineStore, withIntermediateDirectories: true)
        let names = moduleFileNames(in: source)
        for name in names {
            try FileManager.default.copyItem(
                at: source.appendingPathComponent(name),
                to: pristineStore.appendingPathComponent(name))
        }
        return names.count
    }

    /// Ensures a pristine baseline exists, importing from PoP Helper's backup if needed.
    @discardableResult
    func ensurePristineBaseline() throws -> Bool {
        if hasPristineBaseline { return true }
        guard let backup = detectPoPHelperPristineBackup() else { return false }
        try importPristineBaseline(from: backup)
        return hasPristineBaseline
    }

    enum ResetResult {
        case restored(files: Int, safetyBackup: URL)
        case unavailable
    }

    /// Undoes all tweaks by restoring the mod to how it was before PoP Helper touched it,
    /// after taking a timestamped safety backup so the reset itself is undoable.
    ///
    /// Prefers the user's own initial snapshot (preserves third-party mini-mods the user
    /// had installed); only falls back to the bare-vanilla pristine baseline if no snapshot
    /// exists. Using the stale vanilla baseline on a mod that carries extra content would
    /// wipe that content and leave dangling references that crash the game on load.
    func resetToDefaults() throws -> ResetResult {
        let source: URL
        if let snapshot = initialSnapshot(), !moduleFileNames(in: snapshot).isEmpty {
            source = snapshot
        } else if try ensurePristineBaseline() {
            source = pristineStore
        } else {
            return .unavailable
        }
        let names = moduleFileNames(in: source)
        guard !names.isEmpty else { return .unavailable }
        let safety = try backup(files: names)
        try restoreFiles(from: source)
        return .restored(files: names.count, safetyBackup: safety)
    }
}
