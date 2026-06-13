import Foundation

/// Headless status report run by the Swift engine against the real mod folder:
///     swift run PoPHelper --status
/// Mirrors `research/validate_tweaks.py --status`; used to cross-check that the
/// engine agrees with the Python validator on real files.
enum CLI {
    static func statusReport() -> Bool {
        let manager = ModManager()
        guard manager.modFolderExists else {
            print("Mod folder not found: \(manager.modFolder.path)")
            return false
        }
        do {
            let db = try TweakDatabase.load()
            let fileNames = Set(db.tweaks.flatMap { $0.operations.map(\.file) })
            let files = try manager.readFiles(named: fileNames)
            print("Status report against: \(manager.modFolder.path)")
            let width = db.tweaks.map(\.id.count).max() ?? 0
            for tweak in db.tweaks {
                let id = tweak.id.padding(toLength: width + 2, withPad: " ", startingAt: 0)
                switch TweakEngine.status(of: tweak, files: files) {
                case .notApplied:
                    print("  \(id) not applied")
                case .applied(let values):
                    let detail = values.isEmpty
                        ? "applied"
                        : "applied " + values.sorted { $0.key < $1.key }
                            .map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    print("  \(id) \(detail)")
                case .conflict(let why):
                    print("  \(id) conflict (\(why))")
                }
            }
            return true
        } catch {
            print("Error: \(error.localizedDescription)")
            return false
        }
    }
}
