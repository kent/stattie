import XCTest
import SwiftData
@testable import Stattie

@MainActor
final class PositionTrackingTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Game.self,
            PersonGameStats.self,
            Shift.self,
            Stat.self,
            ShiftStat.self,
            User.self,
            Person.self,
            Team.self,
            TeamMembership.self,
            Sport.self,
            StatDefinition.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testStartNewShiftPersistsSelectedPosition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let person = Person(firstName: "Jack", lastName: "Fenwick")
        let game = Game(opponent: "Rivals")
        let player = PersonGameStats(person: person, game: game)
        context.insert(person)
        context.insert(game)
        context.insert(player)

        let shift = player.startNewShift(teamScore: 1, opponentScore: 0, position: .goalkeeper)
        context.insert(shift)

        XCTAssertEqual(shift.recordedPosition, .goalkeeper)
        XCTAssertEqual(shift.positionRawValue, SoccerPosition.goalkeeper.rawValue)
        XCTAssertTrue(shift === player.startNewShift(position: .defender))
        XCTAssertEqual(player.currentShift?.recordedPosition, .goalkeeper)
    }

    func testExistingShiftWithoutPositionReceivesTheNextSelection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let player = PersonGameStats()
        context.insert(player)

        let shift = player.startNewShift()
        context.insert(shift)
        XCTAssertNil(shift.recordedPosition)

        let same = player.startNewShift(position: .hockeyGoalie)
        XCTAssertTrue(same === shift)
        XCTAssertEqual(shift.recordedPosition, .hockeyGoalie)
    }

    func testAggregatorBreaksDownAGameByPosition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let game = Game(opponent: "United")
        let player = PersonGameStats(game: game)
        context.insert(game)
        context.insert(player)

        let defense = player.startNewShift(position: .defender)
        context.insert(defense)
        let tackle = Stat(statName: "TKL", count: 3, personGameStats: player, game: game, shift: defense)
        let saveOnDefense = Stat(statName: "SAV", count: 1, personGameStats: player, game: game, shift: defense)
        context.insert(tackle)
        context.insert(saveOnDefense)
        defense.statRecords = [tackle, saveOnDefense]
        defense.endShift(teamScore: 1, opponentScore: 0)

        let goalie = player.startNewShift(teamScore: 1, opponentScore: 0, position: .goalkeeper)
        context.insert(goalie)
        let save = Stat(statName: "SAV", count: 4, personGameStats: player, game: game, shift: goalie)
        context.insert(save)
        goalie.statRecords = [save]
        goalie.endShift(teamScore: 1, opponentScore: 1)

        let totals = PositionStatAggregator.totals(from: player.shifts ?? [])
        XCTAssertEqual(totals.map(\.position), [.defender, .goalkeeper])

        let defenseTotals = try XCTUnwrap(totals.first { $0.position == .defender })
        XCTAssertEqual(defenseTotals.shiftCount, 1)
        XCTAssertEqual(defenseTotals.count(forName: "TKL"), 3)
        XCTAssertEqual(defenseTotals.plusMinus, 1)

        let goalieTotals = try XCTUnwrap(totals.first { $0.position == .goalkeeper })
        XCTAssertEqual(goalieTotals.count(forName: "SAV"), 4)
        XCTAssertEqual(goalieTotals.plusMinus, -1)

        let goalieLines = PositionStatAggregator.highlightLines(for: goalieTotals, sportName: "Soccer")
        XCTAssertTrue(goalieLines.contains { $0.title == "Saves" && $0.value == "4" })
        XCTAssertFalse(goalieLines.contains { $0.title == "Tackles" })
    }

    func testSeasonTotalsCombineTheSamePositionAcrossGames() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let person = Person(firstName: "Sam")
        context.insert(person)

        func finishedGame(position: SoccerPosition, saves: Int) -> PersonGameStats {
            let game = Game(opponent: "Week", isCompleted: true)
            let stats = PersonGameStats(person: person, game: game)
            context.insert(game)
            context.insert(stats)
            let shift = stats.startNewShift(position: position)
            context.insert(shift)
            let save = Stat(statName: "SAV", count: saves, personGameStats: stats, game: game, shift: shift)
            context.insert(save)
            shift.statRecords = [save]
            shift.endShift()
            return stats
        }

        let first = finishedGame(position: .goalkeeper, saves: 3)
        let second = finishedGame(position: .goalkeeper, saves: 5)
        let third = finishedGame(position: .defender, saves: 0)

        let season = PositionStatAggregator.seasonTotals(from: [first, second, third])
        XCTAssertEqual(season.map(\.position), [.defender, .goalkeeper])
        XCTAssertEqual(season.first { $0.position == .goalkeeper }?.count(forName: "SAV"), 8)
        XCTAssertEqual(season.first { $0.position == .goalkeeper }?.shiftCount, 2)
        XCTAssertEqual(season.first { $0.position == .defender }?.shiftCount, 1)
    }

    func testMembershipAssignmentsWinOverPersonDefaults() {
        let person = Person(
            firstName: "Alex",
            positionAssignments: PositionAssignments(singlePosition: .forward)
        )
        let team = Team(name: "United")
        let membership = TeamMembership(
            person: person,
            team: team,
            positionAssignments: PositionAssignments(assignments: [
                PositionAssignment(position: .defender, percentage: 50),
                PositionAssignment(position: .goalkeeper, percentage: 50),
            ])
        )
        team.memberships = [membership]
        person.teamMemberships = [membership]

        let game = Game(opponent: "City")
        game.team = team

        let resolved = person.positionAssignments(for: game)
        XCTAssertEqual(Set(resolved.positions(for: "Soccer")), [.defender, .goalkeeper])
    }
}
