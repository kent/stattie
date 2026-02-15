import Foundation
import SwiftData

@Model
final class Team {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = ""
    var colorHex: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    var sport: Sport?
    var owner: User?

    @Relationship(deleteRule: .cascade, inverse: \TeamMembership.team)
    var memberships: [TeamMembership]? = []

    @Relationship(deleteRule: .nullify, inverse: \Game.team)
    var games: [Game]? = []

    var members: [Person] {
        (memberships ?? []).compactMap { $0.person }
    }

    var activeMembers: [Person] {
        members.filter { $0.isActive }
    }

    init(
        name: String = "",
        iconName: String = "",
        colorHex: String = "",
        isActive: Bool = true,
        sport: Sport? = nil,
        owner: User? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isActive = isActive
        self.sport = sport
        self.owner = owner
        self.createdAt = Date()
    }
}
