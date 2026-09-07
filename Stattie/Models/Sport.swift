import Foundation
import SwiftData

@Model
final class Sport {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = ""
    var isBuiltIn: Bool = true
    /// Team sports can optionally attach a roster team to a game.
    /// Individual sports like tennis and golf never require one.
    var isTeamSport: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \StatDefinition.sport)
    var statDefinitions: [StatDefinition]? = []

    @Relationship(deleteRule: .nullify, inverse: \Game.sport)
    var games: [Game]? = []

    @Relationship(deleteRule: .nullify, inverse: \Team.sport)
    var teams: [Team]? = []

    var sortedStatDefinitions: [StatDefinition] {
        (statDefinitions ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Shift plus/minus tracking is a team-score concept.
    var usesShiftTracking: Bool { isTeamSport }

    init(
        name: String = "",
        iconName: String = "",
        isBuiltIn: Bool = true,
        isTeamSport: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.isBuiltIn = isBuiltIn
        self.isTeamSport = isTeamSport
    }
}

enum TeamAssociationPolicy {
    /// Offer all of the player's teams before choosing a sport. A stale last-played
    /// sport must never hide a roster for a different sport.
    static func gameMemberships(from memberships: [TeamMembership]) -> [TeamMembership] {
        memberships.filter {
            $0.isActive && $0.team?.isActive == true && $0.team?.sport?.isTeamSport == true
        }.sorted { ($0.team?.name ?? "").localizedCaseInsensitiveCompare($1.team?.name ?? "") == .orderedAscending }
    }

    static func defaultGameMembership(player: Person, from memberships: [TeamMembership]) -> TeamMembership? {
        player.preferredMembership(from: gameMemberships(from: memberships))
    }

}
