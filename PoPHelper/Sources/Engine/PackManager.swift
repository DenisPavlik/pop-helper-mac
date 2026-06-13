import Foundation

enum PackError: LocalizedError {
    case notAvailable(String)
    case noOptionChosen(String)
    case notInstalled(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let id): return "Pack files for \(id) are not in the local library"
        case .noOptionChosen(let id): return "Pick an option for \(id) first"
        case .notInstalled(let id): return "\(id) is not installed"
        }
    }
}

/// Installs / uninstalls cosmetic packs by copying their asset files into the mod
/// (with per-pack backups) and adding/removing module.ini `load_mod_resource`
/// lines for .brf packs. Pack asset files live in `packsLibrary` (not in git).
final class PackManager {
    private static let appSupport = URL(
        fileURLWithPath: NSString(string: "~/Library/Application Support/PoP Helper Mac").expandingTildeInPath)

    static let defaultPacksLibrary = appSupport.appendingPathComponent("Packs")
    static let defaultBackupsRoot = appSupport.appendingPathComponent("PackBackups")
    static let defaultStateFile = appSupport.appendingPathComponent("packs-state.json")

    let modFolder: URL
    let packsLibrary: URL
    let backupsRoot: URL
    let stateFile: URL

    init(modFolder: URL,
         packsLibrary: URL = PackManager.defaultPacksLibrary,
         backupsRoot: URL = PackManager.defaultBackupsRoot,
         stateFile: URL = PackManager.defaultStateFile) {
        self.modFolder = modFolder
        self.packsLibrary = packsLibrary
        self.backupsRoot = backupsRoot
        self.stateFile = stateFile
    }

    private var fm: FileManager { .default }

    // MARK: Availability & state

    func isAvailable(_ pack: Pack) -> Bool {
        let dir = packsLibrary.appendingPathComponent(pack.id)
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: dir.path, isDirectory: &isDir) && isDir.boolValue
    }

    func loadState() -> [String: PackInstallState] {
        guard let data = try? Data(contentsOf: stateFile),
              let s = try? JSONDecoder().decode([String: PackInstallState].self, from: data)
        else { return [:] }
        return s
    }

    private func saveState(_ state: [String: PackInstallState]) throws {
        try fm.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateFile, options: .atomic)
    }

    func installedOption(_ packId: String) -> String? {
        loadState()[packId]?.optionId
    }

    func isInstalled(_ packId: String) -> Bool {
        loadState()[packId] != nil
    }

    // MARK: Mapping expansion

    /// Expands one FileMapping into concrete (source file, target path relative to the mod) pairs.
    private func expand(_ mapping: FileMapping, packDir: URL) -> [(src: URL, rel: String)] {
        // ".ext" → every top-level file with that extension → `to` directory.
        if mapping.from.hasPrefix(".") {
            let ext = String(mapping.from.dropFirst())
            let items = (try? fm.contentsOfDirectory(at: packDir, includingPropertiesForKeys: nil)) ?? []
            return items
                .filter { $0.pathExtension == ext }
                .map { ($0, mapping.to + "/" + $0.lastPathComponent) }
        }
        let src = packDir.appendingPathComponent(mapping.from)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: src.path, isDirectory: &isDir) else { return [] }
        if isDir.boolValue {
            // Directory → copy its whole tree under `to`.
            var result: [(URL, String)] = []
            if let en = fm.enumerator(at: src, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let f as URL in en {
                    let vals = try? f.resourceValues(forKeys: [.isRegularFileKey])
                    if vals?.isRegularFile == true {
                        result.append((f, mapping.to + "/" + relativePath(of: f, under: src)))
                    }
                }
            }
            return result
        }
        // Single file → single target.
        return [(src, mapping.to)]
    }

    private func allPairs(_ pack: Pack, optionId: String?) -> [(src: URL, rel: String)] {
        let packDir = packsLibrary.appendingPathComponent(pack.id)
        return pack.mappings(optionId: optionId).flatMap { expand($0, packDir: packDir) }
    }

    /// Path of `file` relative to `base`, resolving symlinks so /var vs /private/var
    /// (macOS temp dirs) don't break the prefix match.
    private func relativePath(of file: URL, under base: URL) -> String {
        let b = base.resolvingSymlinksInPath().path
        let f = file.resolvingSymlinksInPath().path
        return f.hasPrefix(b + "/") ? String(f.dropFirst(b.count + 1)) : file.lastPathComponent
    }

    private func copyFile(_ src: URL, to dst: URL) throws {
        try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
        try fm.copyItem(at: src, to: dst)
    }

    // MARK: Install / uninstall

    func install(_ pack: Pack, optionId: String?) throws {
        guard isAvailable(pack) else { throw PackError.notAvailable(pack.id) }
        if pack.kind == .choice && optionId == nil { throw PackError.noOptionChosen(pack.id) }

        // Re-install (e.g. switching option) cleanly first.
        if isInstalled(pack.id) { try uninstall(pack) }

        let packBackup = backupsRoot.appendingPathComponent(pack.id)
        if fm.fileExists(atPath: packBackup.path) { try fm.removeItem(at: packBackup) }
        try fm.createDirectory(at: packBackup, withIntermediateDirectories: true)

        var absent: [String] = []
        for (src, rel) in allPairs(pack, optionId: optionId) {
            let dst = modFolder.appendingPathComponent(rel)
            if fm.fileExists(atPath: dst.path) {
                try copyFile(dst, to: packBackup.appendingPathComponent(rel))
            } else {
                absent.append(rel)
            }
            try copyFile(src, to: dst)
        }

        let added = try ensureModuleResources(pack.moduleResources ?? [])
        var state = loadState()
        state[pack.id] = PackInstallState(optionId: optionId, addedResources: added, absentTargets: absent)
        try saveState(state)
    }

    func uninstall(_ pack: Pack) throws {
        var state = loadState()
        guard let st = state[pack.id] else { throw PackError.notInstalled(pack.id) }

        // Restore everything we backed up.
        let packBackup = backupsRoot.appendingPathComponent(pack.id)
        if let en = fm.enumerator(at: packBackup, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let f as URL in en {
                let vals = try? f.resourceValues(forKeys: [.isRegularFileKey])
                guard vals?.isRegularFile == true else { continue }
                let rel = relativePath(of: f, under: packBackup)
                try copyFile(f, to: modFolder.appendingPathComponent(rel))
            }
        }
        // Delete files that didn't exist before install.
        for rel in st.absentTargets {
            let dst = modFolder.appendingPathComponent(rel)
            if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
        }
        try removeModuleResources(st.addedResources)

        state[pack.id] = nil
        try saveState(state)
        if fm.fileExists(atPath: packBackup.path) { try? fm.removeItem(at: packBackup) }
    }

    // MARK: module.ini load_mod_resource lines

    private var moduleIni: URL { modFolder.appendingPathComponent("module.ini") }

    private func readModuleIni() -> [String]? {
        guard let data = try? Data(contentsOf: moduleIni),
              let text = String(data: data, encoding: .isoLatin1) else { return nil }
        return text.components(separatedBy: "\n")
    }

    private func writeModuleIni(_ lines: [String]) throws {
        let text = lines.joined(separator: "\n")
        if let data = text.data(using: .isoLatin1) {
            try data.write(to: moduleIni, options: .atomic)
        }
    }

    private func hasResourceLine(_ lines: [String], _ name: String) -> Bool {
        lines.contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return !t.hasPrefix("#") && t.replacingOccurrences(of: " ", with: "")
                == "load_mod_resource=\(name)"
        }
    }

    @discardableResult
    private func ensureModuleResources(_ names: [String]) throws -> [String] {
        guard !names.isEmpty, var lines = readModuleIni() else { return [] }
        var added: [String] = []
        for name in names where !hasResourceLine(lines, name) {
            let insertAt = lines.lastIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("load_mod_resource") }
            let line = "load_mod_resource = \(name)"
            if let i = insertAt {
                lines.insert(line, at: i + 1)
            } else {
                lines.append(line)
            }
            added.append(name)
        }
        if !added.isEmpty { try writeModuleIni(lines) }
        return added
    }

    private func removeModuleResources(_ names: [String]) throws {
        guard !names.isEmpty, var lines = readModuleIni() else { return }
        let before = lines.count
        lines.removeAll { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return !t.hasPrefix("#") && names.contains { t.replacingOccurrences(of: " ", with: "") == "load_mod_resource=\($0)" }
        }
        if lines.count != before { try writeModuleIni(lines) }
    }
}
