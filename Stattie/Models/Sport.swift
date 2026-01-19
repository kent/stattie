import Foundation
import SwiftData

@Model
final class Sport {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = ""
    var isBuiltIn: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \StatDefinition.sport)
    var statDefinitions: [StatDefinition]? = []

    @Relationship(deleteRule: .nullify, inverse: \Game.sport)
    var games: [Game]? = []

    var sortedStatDefinitions: [StatDefinition] {
        (statDefinitions ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    init(name: String = "", iconName: String = "", isBuiltIn: Bool = true) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.isBuiltIn = isBuiltIn
    }
}
