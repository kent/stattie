import XCTest
import SwiftData
@testable import Stattie

@MainActor
final class TeamMembershipTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = SharedModelContainer.schema
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

        XCTAssertTrue(team.activeMembers.isEmpty)
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

    func testIndividualSportNeverOffersOrDefaultsATeam() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tennis = Sport(name: "Tennis", iconName: "tennisball.fill", isTeamSport: false)
        let player = Person(firstName: "Sofia", lastName: "Reyes", prefersNoTeam: true)
        let club = Team(name: "City Club", sport: tennis)
        context.insert(tennis)
        context.insert(player)
        context.insert(club)

        let membership = TeamMembership(person: player, team: club, role: "player", isActive: true)
        context.insert(membership)
        player.teamMemberships = [membership]
        try context.save()

        XCTAssertTrue(TeamAssociationPolicy.gameMemberships(from: player.activeTeamMemberships).isEmpty)
        XCTAssertNil(TeamAssociationPolicy.defaultGameMembership(player: player, from: player.activeTeamMemberships))
    }

    func testTennisGameCanBeTrackedWithoutATeam() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let user = User(displayName: "Parent")
        let tennis = Sport(name: "Tennis", iconName: "tennisball.fill", isTeamSport: false)
        let ace = StatDefinition(name: "Ace", shortName: "ACE", category: "serve", sport: tennis)
        let player = Person(firstName: "Alex", lastName: "Kim", prefersNoTeam: true, owner: user)
        context.insert(user)
        context.insert(tennis)
        context.insert(ace)
        tennis.statDefinitions = [ace]
        context.insert(player)

        let game = Game(opponent: "Jordan", sport: tennis, trackedBy: user)
        XCTAssertNil(game.team)
        context.insert(game)

        let personStats = PersonGameStats(person: player, game: game)
        context.insert(personStats)
        game.personStats = [personStats]
        try context.save()

        _ = try game.recordStat(
            named: "ACE",
            pointValue: 0,
            mutation: .count,
            personGameStats: personStats,
            in: context
        )
        try context.save()

        XCTAssertNil(game.team)
        XCTAssertEqual(game.totalCount(forName: "ACE"), 1)
        XCTAssertEqual(game.listSummaryValue, 1)
        XCTAssertEqual(game.listSummaryLabel, "aces")
        XCTAssertFalse(tennis.usesShiftTracking)
        XCTAssertFalse(player.shouldPromptForTeamAssociation)
    }

    func testBasketballGameCanStartWithoutATeam() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let user = User(displayName: "Parent")
        let basketball = Sport(name: "Basketball", iconName: "basketball.fill", isTeamSport: true)
        let player = Person(firstName: "Jordan", lastName: "Lee", prefersNoTeam: true, owner: user)
        context.insert(user)
        context.insert(basketball)
        context.insert(player)

        let game = Game(opponent: "", sport: basketball, trackedBy: user)
        context.insert(game)
        let personStats = PersonGameStats(person: player, game: game)
        context.insert(personStats)
        game.personStats = [personStats]

        _ = try game.recordStat(
            named: "2PT",
            pointValue: 2,
            mutation: .made,
            personGameStats: personStats,
            in: context
        )
        try context.save()

        XCTAssertNil(game.team)
        XCTAssertEqual(game.totalPoints, 2)
        XCTAssertTrue(basketball.usesShiftTracking)
        XCTAssertTrue(TeamAssociationPolicy.gameMemberships(from: []).isEmpty)
    }
    func testNewGameChoosesTeamBeforeUnrelatedLastPlayedSport() {
        let football = Sport(name: "American Football")
        let soccer = Sport(name: "Soccer")
        let player = Person(firstName: "Emma")
        let team = Team(name: "United", sport: soccer)
        let membership = TeamMembership(person: player, team: team)
        let previousGame = Game(sport: football)
        player.gameStats = [PersonGameStats(person: player, game: previousGame)]

        let selected = TeamAssociationPolicy.defaultGameMembership(player: player, from: [membership])
        XCTAssertEqual(selected?.team?.id, team.id)
        XCTAssertEqual(selected?.team?.sport?.name, "Soccer")
    }

    func testNewGameOffersTeamsAcrossSportsAndExcludesArchivedMemberships() {
        let soccer = Sport(name: "Soccer")
        let hockey = Sport(name: "Ice Hockey")
        let tennis = Sport(name: "Tennis", isTeamSport: false)
        let first = TeamMembership(team: Team(name: "United", sport: soccer))
        let second = TeamMembership(team: Team(name: "Lions", sport: hockey))
        let inactive = TeamMembership(team: Team(name: "Old", sport: soccer), isActive: false)
        let archived = TeamMembership(team: Team(name: "Archived", isActive: false, sport: soccer))
        let club = TeamMembership(team: Team(name: "Club", sport: tennis))
        let available = TeamAssociationPolicy.gameMemberships(from: [first, inactive, club, archived, second])
        XCTAssertEqual(available.map(\.id), [second.id, first.id])
    }

    func testMultipleMembershipPositionsPersistIndependentlyBySport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let person = Person(firstName: "Emma", positionAssignments: PositionAssignments(singlePosition: .pointGuard))
        let soccer = Sport(name: "Soccer")
        let team = Team(name: "United", sport: soccer)
        let assignments = PositionAssignments(assignments: [
            PositionAssignment(position: .defender, percentage: 50),
            PositionAssignment(position: .goalkeeper, percentage: 50)
        ])
        let membership = TeamMembership(person: person, team: team, positionAssignments: assignments)
        context.insert(person)
        context.insert(team)
        context.insert(membership)
        try context.save()
        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<TeamMembership>()).first)
        XCTAssertEqual(Set(restored.positionAssignments.positions(for: "Soccer")), [.defender, .goalkeeper])
        XCTAssertTrue(restored.hasMultiplePositions)
        XCTAssertEqual(person.positionAssignments.primaryPosition, .pointGuard)
    }

}
