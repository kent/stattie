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
    /// Only team sports with a matching membership should offer a team picker.
    static func shouldOfferTeamPicker(sport: Sport?, memberships: [TeamMembership]) -> Bool {
        guard let sport, sport.isTeamSport else { return false }
        return !membershipsMatching(sport: sport, from: memberships).isEmpty
    }

    /// Individual sports never preselect a team. Team sports prefer the last used matching team.
    static func defaultMembership(
        for sport: Sport?,
        player: Person,
        from memberships: [TeamMembership]
    ) -> TeamMembership? {
        guard let sport, sport.isTeamSport else { return nil }
        return player.preferredMembership(from: membershipsMatching(sport: sport, from: memberships))
    }

    static func membershipsMatching(sport: Sport, from memberships: [TeamMembership]) -> [TeamMembership] {
        memberships.filter { $0.team?.sport?.id == sport.id }
    }
}
