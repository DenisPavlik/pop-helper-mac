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
    /// Short, plain-language guidance shown when the tweak is expanded: what the
    /// recommended value gives and which direction to tune. Optional.
    var recommendation: LocalizedText? = nil
    /// Marked with `*` in the original PoP Helper: only takes effect on a NEW game
    /// (or only affects a new character). Safe to apply to an existing save, but
    /// won't change it retroactively. Optional (absent = false).
    var requiresNewGame: Bool? = nil
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
    /// The vanilla pattern is entirely gone and our applied form isn't present either —
    /// this spot was changed by something other than PoP Helper Mac. In practice that means
    /// the original Windows PoP Helper already applied this tweak in its own byte form, so the
    /// tweak is active in-game; we just can't recognise/toggle that exact variant. Shown as
    /// "already applied" and locked (not a scary "conflict").
    case appliedExternally(detail: String)
    /// Partial/ambiguous state (some occurrences vanilla, some changed) — a genuine conflict.
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
