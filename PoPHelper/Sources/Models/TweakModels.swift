import Foundation

// MARK: - Database models (mirror docs/tweak-db-format.md, schemaVersion 1)

struct TweakDatabase: Codable {
    let schemaVersion: Int
    let gameVersion: String
    let tweaks: [Tweak]
}

struct LocalizedText: Codable, Hashable {
    let en: String
    let uk: String
    var ru: String?

    init(en: String, uk: String, ru: String? = nil) {
        self.en = en
        self.uk = uk
        self.ru = ru
    }

    func text(for language: AppLanguage) -> String {
        switch language {
        case .english: return en
        case .ukrainian: return uk
        case .russian: return ru ?? uk   // fall back to Ukrainian until ru is filled in
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case ukrainian = "uk"
    case russian = "ru"
    case english = "en"
    var id: String { rawValue }
}

struct Tweak: Codable, Identifiable, Hashable {
    let id: String
    let name: LocalizedText
    let description: LocalizedText
    let category: String
    let wikiRef: String?
    let params: [TweakParam]
    let operations: [TweakOperation]
}

struct TweakParam: Codable, Hashable {
    let key: String
    let name: LocalizedText
    let originalValue: Int
    let defaultValue: Int
    let min: Int?
    let max: Int?
    let presets: [ParamPreset]?
}

struct ParamPreset: Codable, Hashable {
    let value: Int
    let label: LocalizedText
}

struct TweakOperation: Codable, Hashable {
    let file: String
    let original: String
    let replacement: String
    let occurrence: Occurrence
    let expectedCount: Int
    /// True when `replacement` is a rewritten block rather than `original`
    /// with different numbers; see docs/tweak-db-format.md.
    var structural: Bool? = nil

    var isStructural: Bool { structural ?? false }
}

/// "all" or a 1-based list of indices among the matches of `original`.
enum Occurrence: Codable, Hashable {
    case all
    case indices([Int])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self), s == "all" {
            self = .all
        } else if let list = try? container.decode([Int].self) {
            self = .indices(list)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "occurrence must be \"all\" or an array of 1-based indices")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .all: try container.encode("all")
        case .indices(let list): try container.encode(list)
        }
    }
}

// MARK: - Runtime state

enum TweakStatus: Equatable {
    /// Pristine values found in the file.
    case notApplied
    /// Tweak detected; current parameter values read back from the file.
    case applied(values: [String: Int])
    /// Neither pristine nor tweaked form matches — file was changed by something else.
    case conflict(detail: String)
}

extension TweakDatabase {
    static func load() throws -> TweakDatabase {
        guard let url = Bundle.module.url(forResource: "tweaks", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }

    static func load(from url: URL) throws -> TweakDatabase {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TweakDatabase.self, from: data)
    }
}
