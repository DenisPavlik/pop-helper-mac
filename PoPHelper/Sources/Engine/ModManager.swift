import Foundation

/// Locates the mod folder, reads/writes module files with byte-exact round-tripping,
/// and snapshots files into timestamped backups before any write.
final class ModManager {

    static let defaultModPath = NSString(
        string: "~/Library/Application Support/Steam/steamapps/common/MountBlade Warband/Modules/Prophesy of Pendor V3.9.5"
    ).expandingTildeInPath

    static let backupsRoot = URL(
        fileURLWithPath: NSString(string: "~/Library/Application Support/PoP Helper Mac/Backups").expandingTildeInPath)

    private(set) var modFolder: URL

    init(modFolder: URL) {
        self.modFolder = modFolder
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
    func backup(files names: some Sequence<String>) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dir = Self.backupsRoot.appendingPathComponent(formatter.string(from: Date()))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in Set(names) {
            let src = modFolder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: src.path) else { continue }
            try FileManager.default.copyItem(at: src, to: dir.appendingPathComponent(name))
        }
        return dir
    }

    func listBackups() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Self.backupsRoot, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func restore(backup dir: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        for src in files where src.pathExtension == "txt" || src.lastPathComponent == "module.ini" {
            let dst = modFolder.appendingPathComponent(src.lastPathComponent)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: src, to: dst)
        }
    }
}
