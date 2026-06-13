import SwiftUI

/// Display metadata for tweak categories: SF Symbol icon, stable ordering, accent tint.
enum CategoryMeta {
    /// Preferred sidebar order; unknown categories are appended after these.
    static let order = [
        "spawns", "parties", "world", "battle", "troops", "tournaments",
        "noldor", "companions", "prisoners", "kingdom", "economy", "items",
        "quests", "cheats", "other",
    ]

    static func icon(_ category: String) -> String {
        switch category {
        case "spawns": return "flag.checkered"
        case "parties": return "person.3.fill"
        case "world": return "globe.europe.africa.fill"
        case "battle": return "burst.fill"
        case "troops": return "shield.lefthalf.filled"
        case "tournaments": return "trophy.fill"
        case "noldor": return "sparkles"
        case "companions": return "person.2.fill"
        case "prisoners": return "lock.fill"
        case "kingdom": return "crown.fill"
        case "economy": return "dollarsign.circle.fill"
        case "items": return "bag.fill"
        case "quests": return "scroll.fill"
        case "cheats": return "wand.and.stars"
        default: return "slider.horizontal.3"
        }
    }

    static func tint(_ category: String) -> Color {
        switch category {
        case "spawns": return .red
        case "parties": return .purple
        case "world": return .cyan
        case "battle": return .pink
        case "troops": return .blue
        case "tournaments": return .orange
        case "noldor": return .teal
        case "companions": return .indigo
        case "prisoners": return .brown
        case "kingdom": return .yellow
        case "economy": return .green
        case "items": return .mint
        case "quests": return .orange
        case "cheats": return .gray
        default: return .gray
        }
    }

    /// Sorts a set of category ids into `order`, with any extras appended.
    static func sorted(_ categories: [String]) -> [String] {
        let known = order.filter(categories.contains)
        let extra = categories.filter { !order.contains($0) }
        return known + extra
    }
}
