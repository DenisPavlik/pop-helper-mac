import SwiftUI

/// Display metadata for tweak categories: SF Symbol icon, stable ordering, accent.
enum CategoryMeta {
    /// Preferred sidebar order; unknown categories are appended after these.
    static let order = ["spawns", "tournaments", "noldor", "companions", "prisoners", "economy", "other"]

    static func icon(_ category: String) -> String {
        switch category {
        case "spawns": return "flag.checkered"
        case "tournaments": return "trophy.fill"
        case "noldor": return "sparkles"
        case "companions": return "person.2.fill"
        case "prisoners": return "lock.fill"
        case "economy": return "dollarsign.circle.fill"
        default: return "slider.horizontal.3"
        }
    }

    static func tint(_ category: String) -> Color {
        switch category {
        case "spawns": return .red
        case "tournaments": return .orange
        case "noldor": return .teal
        case "companions": return .indigo
        case "prisoners": return .brown
        case "economy": return .green
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
