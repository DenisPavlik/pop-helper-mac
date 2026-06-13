import Foundation

// MARK: - Cosmetic pack manifest (PoPHelper/Resources/packs.json)
// Pack ASSET files live locally in ModManager.packsLibrary (third-party mods,
// not bundled). This manifest only describes how to install them.

struct PackDatabase: Codable {
    let schemaVersion: Int
    let packs: [Pack]

    static func load() throws -> PackDatabase {
        guard let url = Bundle.module.url(forResource: "packs", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(PackDatabase.self, from: Data(contentsOf: url))
    }
}

enum PackKind: String, Codable {
    case copy    // copy a fixed set of files
    case choice  // user picks one option
}

/// A file/dir mapping from inside the pack folder to a path inside the mod.
/// `from` may be: a file, a directory (copy its tree), or ".ext" (all files
/// with that extension in the pack root → the `to` directory).
struct FileMapping: Codable, Hashable {
    let from: String
    let to: String
}

struct PackOption: Codable, Identifiable, Hashable {
    let id: String
    let name: LocalizedText
    var preview: String?      // path inside the pack folder to a preview image
    let files: [FileMapping]
}

struct Pack: Codable, Identifiable {
    let id: String
    let name: LocalizedText
    let description: LocalizedText
    let kind: PackKind
    var files: [FileMapping]?
    var options: [PackOption]?
    var moduleResources: [String]?

    /// File mappings to apply for the given option (choice packs) or the fixed set (copy packs).
    func mappings(optionId: String?) -> [FileMapping] {
        switch kind {
        case .copy:
            return files ?? []
        case .choice:
            guard let optionId, let opt = options?.first(where: { $0.id == optionId }) else { return [] }
            return opt.files
        }
    }
}

// MARK: - Runtime install state (persisted to packs-state.json)

struct PackInstallState: Codable {
    var optionId: String?
    var addedResources: [String]   // module.ini load_mod_resource lines we added
    var absentTargets: [String]    // targets that didn't exist before install → delete on uninstall
}
