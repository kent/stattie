import XCTest
import SwiftData
@testable import Stattie

@MainActor
final class TeamMembershipTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            User.self,
            Person.self,
            Team.self,
            TeamMembership.self,
            Sport.self,
            StatDefinition.self,
            Game.self,
            PersonGameStats.self,
            Stat.self,
            Shift.self,
            ShiftStat.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testPlayerCanBelongToMultipleTeams() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let basketball = Sport(name: "Basketball", iconName: "basketball.fill")
        let soccer = Sport(name: "Soccer", iconName: "soccerball")
        let player = Person(firstName: "Maya", lastName: "Chen")
        let lions = Team(name: "Lions", sport: basketball)
        let united = Team(name: "United", sport: soccer)

        context.insert(basketball)
        context.insert(soccer)
        context.insert(player)
        context.insert(lions)
        context.insert(united)

        let lionsMembership = TeamMembership(person: player, team: lions, role: "player", isActive: true)
        let unitedMembership = TeamMembership(person: player, team: united, role: "player", isActive: true)
        context.insert(lionsMembership)
        context.insert(unitedMembership)
        player.teamMemberships = [lionsMembership, unitedMembership]
        lions.memberships = [lionsMembership]
        united.memberships = [unitedMembership]

        try context.save()

        XCTAssertEqual(player.activeTeams.count, 2)
        XCTAssertTrue(player.isMember(of: lions))
        XCTAssertTrue(player.isMember(of: united))
        XCTAssertEqual(lions.sport?.name, "Basketball")
        XCTAssertEqual(united.sport?.name, "Soccer")
    }

    func testInactiveMembershipIsExcludedFromActiveTeams() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let sport = Sport(name: "Basketball", iconName: "basketball.fill")
        let player = Person(firstName: "Jordan", lastName: "Lee")
        let team = Team(name: "Tigers", sport: sport)
        context.insert(sport)
        context.insert(player)
        context.insert(team)

        let membership = TeamMembership(person: player, team: team, role: "player", isActive: false)
        context.insert(membership)
        player.teamMemberships = [membership]
        team.memberships = [membership]
        try context.save()

        XCTAssertTrue(player.activeTeams.isEmpty)
        XCTAssertFalse(player.isMember(of: team))
        XCTAssertTrue(player.shouldPromptForTeamAssociation)
    }

    func testUnassociatedPlayerShouldBePromptedForTeam() throws {
        let player = Person(firstName: "Alex", lastName: "Kim")
        XCTAssertTrue(player.shouldPromptForTeamAssociation)
    }

    func testPlayerWhoContinuedWithoutATeamIsNotPromptedAgain() throws {
        let player = Person(firstName: "Sofia", lastName: "Reyes", prefersNoTeam: true)
        XCTAssertFalse(player.shouldPromptForTeamAssociation)
    }

    func testPlayerAlreadyOnATeamIsNotPrompted() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let sport = Sport(name: "Basketball", iconName: "basketball.fill")
        let player = Person(firstName: "Maya", lastName: "Chen")
        let lions = Team(name: "Lions", sport: sport)
        context.insert(sport)
        context.insert(player)
        context.insert(lions)

        let membership = TeamMembership(person: player, team: lions, role: "player", isActive: true)
        context.insert(membership)
        player.teamMemberships = [membership]
        lions.memberships = [membership]
        try context.save()

        XCTAssertFalse(player.shouldPromptForTeamAssociation)
    }

    func testPreferredMembershipUsesOnlyMembership() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let sport = Sport(name: "Tennis", iconName: "tennisball.fill")
        let player = Person(firstName: "Naomi", lastName: "Osaka")
        let club = Team(name: "City Club", sport: sport)
        context.insert(sport)
        context.insert(player)
        context.insert(club)

        let membership = TeamMembership(person: player, team: club, role: "player", isActive: true)
        context.insert(membership)
        player.teamMemberships = [membership]
        try context.save()

        XCTAssertEqual(player.preferredMembership(from: player.activeTeamMemberships)?.id, membership.id)
    }

    func testPreferredMembershipPrefersMostRecentGameTeam() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let basketball = Sport(name: "Basketball", iconName: "basketball.fill")
        let soccer = Sport(name: "Soccer", iconName: "soccerball")
        let player = Person(firstName: "Maya", lastName: "Chen")
        let lions = Team(name: "Lions", sport: basketball)
        let united = Team(name: "United", sport: soccer)
        context.insert(basketball)
        context.insert(soccer)
        context.insert(player)
        context.insert(lions)
        context.insert(united)

        let lionsMembership = TeamMembership(person: player, team: lions, role: "player", isActive: true)
        let unitedMembership = TeamMembership(person: player, team: united, role: "player", isActive: true)
        context.insert(lionsMembership)
        context.insert(unitedMembership)
        player.teamMemberships = [lionsMembership, unitedMembership]

        let olderGame = Game(gameDate: Date().addingTimeInterval(-86_400), opponent: "Tigers")
        olderGame.team = lions
        let newerGame = Game(gameDate: Date(), opponent: "Sharks")
        newerGame.team = united
        context.insert(olderGame)
        context.insert(newerGame)

        let olderStats = PersonGameStats(person: player, game: olderGame)
        let newerStats = PersonGameStats(person: player, game: newerGame)
        context.insert(olderStats)
        context.insert(newerStats)
        player.gameStats = [olderStats, newerStats]
        try context.save()

        XCTAssertEqual(
            player.preferredMembership(from: player.activeTeamMemberships)?.id,
            unitedMembership.id
        )
    }

    func testPreferredMembershipIsNilWhenPlayerHasNoTeams() throws {
        let player = Person(firstName: "Solo", lastName: "Player")
        XCTAssertNil(player.preferredMembership(from: player.activeTeamMemberships))
    }
}
