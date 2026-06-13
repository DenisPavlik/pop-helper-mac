import Foundation

/// One `rgl_config.txt` value in a curated profile, plus how to serialize it.
/// Ints write as `25`; floats write as `1.0000` (the game's own format).
struct GameConfigValue {
    let key: String
    let value: Double
    let isFloat: Bool

    var formatted: String { isFloat ? String(format: "%.4f", value) : String(Int(value.rounded())) }

    static func float(_ key: String, _ value: Double) -> GameConfigValue {
        GameConfigValue(key: key, value: value, isFloat: true)
    }
    static func int(_ key: String, _ value: Int) -> GameConfigValue {
        GameConfigValue(key: key, value: Double(value), isFloat: false)
    }
}

/// The handful of rgl_config values worth setting from outside the game's own Video
/// menu — the ones that are easy to get wrong and matter most on Apple Silicon.
enum GamePerformance {
    /// Approx. soldiers on the field when `battle_size = 1.0` — Warband's cap without
    /// an .exe patch (raising it further is deferred; risky).
    static let maxBattleTroops = 150

    /// Curated optimal values for Apple Silicon (M-series) Macs:
    /// max battle size (fixes "too few archers"), heavy shadows off (biggest FPS win),
    /// moderate grass. Everything else is left exactly as the in-game menu has it.
    static let macProfile: [GameConfigValue] = [
        .float("battle_size", 1.0),
        .int("enable_accurate_shadows", 0),
        .int("enable_environment_shadows", 0),
        .int("realistic_shadows_on_plants", 0),
        .int("grass_density", 25),
    ]

    /// True if every profile key in `current` already matches the curated value.
    static func isOptimal(_ current: [String: Double]) -> Bool {
        macProfile.allSatisfy { setting in
            guard let v = current[setting.key] else { return false }
            return abs(v - setting.value) < 1e-6
        }
    }

    /// The profile as `key -> formatted string`, ready for `GameConfigManager.write`.
    static var formattedProfile: [String: String] {
        Dictionary(uniqueKeysWithValues: macProfile.map { ($0.key, $0.formatted) })
    }
}
