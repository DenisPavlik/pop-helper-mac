import SwiftUI

/// Display metadata for tweak categories: SF Symbol icon, stable ordering, accent tint.
enum CategoryMeta {
    /// Sidebar order mirrors the original PoP Helper's tweak tabs.
    static let order = [
        "party", "tournaments", "towns", "prisoners", "battle",
        "orders", "lords", "honor", "misc", "spawns", "other",
    ]

    static func icon(_ category: String) -> String {
        switch category {
        case "party": return "person.3.fill"
        case "tournaments": return "trophy.fill"
        case "towns": return "building.2.fill"
        case "prisoners": return "lock.fill"
        case "battle": return "burst.fill"
        case "orders": return "shield.lefthalf.filled"
        case "lords": return "crown.fill"
        case "honor": return "hand.raised.fill"
        case "misc": return "ellipsis.circle.fill"
        case "spawns": return "flag.checkered"
        default: return "slider.horizontal.3"
        }
    }

    static func tint(_ category: String) -> Color {
        switch category {
        case "party": return .purple
        case "tournaments": return .orange
        case "towns": return .green
        case "prisoners": return .brown
        case "battle": return .pink
        case "orders": return .blue
        case "lords": return .yellow
        case "honor": return .teal
        case "misc": return .gray
        case "spawns": return .red
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
