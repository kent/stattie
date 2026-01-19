import Foundation
import SwiftData

@Model
final class StatDefinition {
    var id: UUID = UUID()
    var name: String = ""
    var shortName: String = ""
    var category: String = ""
    var hasMadeAndMissed: Bool = false
    var pointValue: Int = 0
    var sortOrder: Int = 0
    var iconName: String = ""

    var sport: Sport?

    init(
        name: String = "",
        shortName: String = "",
        category: String = "",
        hasMadeAndMissed: Bool = false,
        pointValue: Int = 0,
        sortOrder: Int = 0,
        iconName: String = "",
        sport: Sport? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.shortName = shortName
        self.category = category
        self.hasMadeAndMissed = hasMadeAndMissed
        self.pointValue = pointValue
        self.sortOrder = sortOrder
        self.iconName = iconName
        self.sport = sport
    }
}

extension StatDefinition {
    static let categoryOrder: [String] = ["shooting", "rebounding", "defense", "other"]

    var categoryIndex: Int {
        Self.categoryOrder.firstIndex(of: category) ?? Self.categoryOrder.count
    }
}
