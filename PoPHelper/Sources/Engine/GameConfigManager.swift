import Foundation

/// Reads/writes Warband's global `rgl_config.txt` (the GAME engine config, not the
/// mod). Format is `key = value`, one per line, separated by blank lines. Edits
/// rewrite ONLY the value of known keys, preserving exact formatting, line order,
/// blank lines and any keys we don't manage. A timestamped backup is taken before
/// each write.
final class GameConfigManager {

    static let defaultConfigURL = URL(fileURLWithPath: NSString(
        string: "~/Library/Application Support/MBWarband/rgl_config.txt").expandingTildeInPath)

    static let defaultBackupsRoot = URL(fileURLWithPath: NSString(
        string: "~/Library/Application Support/PoP Helper Mac/GameConfigBackups").expandingTildeInPath)

    let configURL: URL
    let backupsRoot: URL

    init(configURL: URL = GameConfigManager.defaultConfigURL,
         backupsRoot: URL = GameConfigManager.defaultBackupsRoot) {
        self.configURL = configURL
        self.backupsRoot = backupsRoot
    }

    var exists: Bool { FileManager.default.fileExists(atPath: configURL.path) }

    // MARK: Parsing

    /// Splits a single `key = value` line. Returns nil for blank/comment/unparseable
    /// lines. The key must be a bare identifier; the value must be non-empty.
    static func parseLine(_ line: String) -> (key: String, value: String)? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let key = line[..<eq].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty,
              key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
        return (key, value)
    }

    // MARK: IO
    // Read/write as ISO-Latin-1 so untouched lines round-trip byte-exactly even if a
    // value isn't valid UTF-8 (it always is here — plain ASCII — but stay faithful).

    private func rawText() throws -> String {
        let data = try Data(contentsOf: configURL)
        return String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)
    }

    /// Every numeric `key = value` pair currently in the file.
    func read() throws -> [String: Double] {
        var result: [String: Double] = [:]
        for line in try rawText().components(separatedBy: "\n") {
            if let (key, value) = Self.parseLine(line), let number = Double(value) {
                result[key] = number
            }
        }
        return result
    }

    /// Rewrites the given keys with already-formatted string values, leaving every
    /// other byte of the file untouched. Keys not present in the file are appended.
    func write(_ formatted: [String: String]) throws {
        var out: [String] = []
        var written: Set<String> = []
        for line in try rawText().components(separatedBy: "\n") {
            if let (key, _) = Self.parseLine(line), let newValue = formatted[key],
               let eq = line.firstIndex(of: "=") {
                out.append("\(line[...eq]) \(newValue)")   // keep "key =" prefix verbatim
                written.insert(key)
            } else {
                out.append(line)
            }
        }
        for (key, value) in formatted.sorted(by: { $0.key < $1.key }) where !written.contains(key) {
            if let last = out.last, !last.isEmpty { out.append("") }
            out.append("\(key) = \(value)")
        }
        let text = out.joined(separator: "\n")
        try (text.data(using: .isoLatin1) ?? Data(text.utf8)).write(to: configURL, options: .atomic)
    }

    // MARK: Backup

    /// Copies the current `rgl_config.txt` into a timestamped file; returns its URL.
    @discardableResult
    func backup() throws -> URL {
        try FileManager.default.createDirectory(at: backupsRoot, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dest = backupsRoot.appendingPathComponent("rgl_config \(formatter.string(from: Date())).txt")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: configURL, to: dest)
        return dest
    }
}
