import XCTest
import SwiftData
@testable import Stattie

@MainActor
final class CanonicalStatModelTests: XCTestCase {
    private enum TestFailure: Error { case injectedSaveFailure }

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

    private func insertGameGraph(
        in context: ModelContext,
        playerCount: Int = 1
    ) -> (Game, [PersonGameStats]) {
        let game = Game(opponent: "Test")
        context.insert(game)
        var players: [PersonGameStats] = []
        for index in 0..<playerCount {
            let person = Person(firstName: "Player \(index + 1)")
            let personStats = PersonGameStats(person: person, game: game)
            context.insert(person)
            context.insert(personStats)
            if game.personStats == nil { game.personStats = [] }
            game.personStats?.append(personStats)
            players.append(personStats)
        }
        return (game, players)
    }

    func testTotalsSumDistinctCanonicalRowsAndDeduplicateSameUUIDAcrossInverses() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (game, players) = insertGameGraph(in: context)
        let player = try XCTUnwrap(players.first)
        let shift = player.startNewShift()
        context.insert(shift)

        let shifted = Stat(
            statName: "2PT",
            pointValue: 2,
            made: 2,
            missed: 1,
            personGameStats: player,
            game: game,
            shift: shift
        )
        let unshifted = Stat(
            statName: "2PT",
            pointValue: 2,
            made: 1,
            missed: 2,
            personGameStats: player,
            game: game
        )
        context.insert(shifted)
        context.insert(unshifted)
        game.stats = [shifted, unshifted, shifted]
        player.stats = [shifted, unshifted, shifted]
        shift.statRecords = [shifted, shifted]

        XCTAssertEqual(game.canonicalStats.count, 2)
        XCTAssertEqual(game.totalPoints, 6)
        XCTAssertEqual(game.totalMade(forName: "2PT"), 3)
        XCTAssertEqual(game.totalMissed(forName: "2PT"), 3)
        XCTAssertEqual(player.totalPoints, 6)
        XCTAssertEqual(player.aggregatedMade(forName: "2PT"), 3)
        XCTAssertEqual(shift.totalPoints, 4)
        XCTAssertEqual(shift.totalMade(forName: "2PT"), 2)
    }

    func testMultiPlayerAttributionSumsRatherThanChoosingLargestMirror() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (game, players) = insertGameGraph(in: context, playerCount: 2)
        let first = players[0]
        let second = players[1]

        _ = try game.recordStat(
            named: "3PT",
            pointValue: 3,
            mutation: .made,
            personGameStats: first,
            in: context
        )
        _ = try game.recordStat(
            named: "3PT",
            pointValue: 3,
            mutation: .made,
            personGameStats: second,
            in: context
        )
        _ = try game.recordStat(
            named: "AST",
            pointValue: 0,
            mutation: .count,
            personGameStats: second,
            in: context
        )

        XCTAssertEqual(game.stats(named: "3PT").count, 2)
        XCTAssertEqual(game.totalMade(forName: "3PT"), 2)
        XCTAssertEqual(game.totalPoints, 6)
        XCTAssertEqual(first.totalPoints, 3)
        XCTAssertEqual(second.totalPoints, 3)
        XCTAssertEqual(second.totalAssists, 1)
    }

    func testShiftLifecycleIsSingleActiveShiftAndCapturesScoreAndTime() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (_, players) = insertGameGraph(in: context)
        let player = players[0]

        let first = player.startNewShift(teamScore: 10, opponentScore: 8)
        context.insert(first)
        XCTAssertTrue(first === player.startNewShift(teamScore: 99, opponentScore: 99))
        let endDate = Date(timeIntervalSince1970: 1_000)
        first.endShift(teamScore: 17, opponentScore: 12, at: endDate)

        XCTAssertEqual(first.endTime, endDate)
        XCTAssertEqual(first.plusMinus, 3)
        XCTAssertFalse(player.hasActiveShift)

        let second = player.startNewShift(teamScore: 17, opponentScore: 12)
        context.insert(second)
        XCTAssertEqual(second.shiftNumber, 2)
        XCTAssertTrue(player.currentShift === second)
    }

    func testCentralRecordAndUndoUseExactPlayerAndShiftAttribution() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (game, players) = insertGameGraph(in: context, playerCount: 2)
        let first = players[0]
        let second = players[1]
        let firstShift = first.startNewShift()
        context.insert(firstShift)

        let record = try game.recordStat(
            named: "FT",
            pointValue: 1,
            mutation: .made,
            personGameStats: first,
            shift: firstShift,
            in: context
        )
        _ = try game.recordStat(
            named: "FT",
            pointValue: 1,
            mutation: .made,
            personGameStats: first,
            shift: firstShift,
            in: context
        )

        XCTAssertEqual(record.made, 2)
        XCTAssertEqual(game.canonicalStats.count, 1)
        XCTAssertEqual(firstShift.canonicalStats.count, 1)
        XCTAssertTrue(try game.undoStat(
            named: "FT",
            mutation: .made,
            personGameStats: first,
            shift: firstShift
        ))
        XCTAssertTrue(try game.undoStat(
            named: "FT",
            mutation: .made,
            personGameStats: first,
            shift: firstShift
        ))
        XCTAssertFalse(try game.undoStat(
            named: "FT",
            mutation: .made,
            personGameStats: first,
            shift: firstShift
        ))
        XCTAssertEqual(record.made, 0)

        XCTAssertThrowsError(try game.recordStat(
            named: "AST",
            pointValue: 0,
            mutation: .count,
            shift: firstShift,
            in: context
        )) { error in
            XCTAssertEqual(error as? StatAttributionError, .shiftRequiresPerson)
        }
        XCTAssertThrowsError(try game.recordStat(
            named: "AST",
            pointValue: 0,
            mutation: .count,
            personGameStats: second,
            shift: firstShift,
            in: context
        )) { error in
            XCTAssertEqual(error as? StatAttributionError, .shiftBelongsToDifferentPerson)
        }

        let otherGame = Game(opponent: "Other")
        context.insert(otherGame)
        XCTAssertThrowsError(try otherGame.recordStat(
            named: "AST",
            pointValue: 0,
            mutation: .count,
            personGameStats: first,
            in: context
        )) { error in
            XCTAssertEqual(error as? StatAttributionError, .personBelongsToDifferentGame)
        }
    }

    func testFinalizeClosesEveryActiveShiftSavesOnceAndIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let user = User(displayName: "Tracker")
        let (game, players) = insertGameGraph(in: context, playerCount: 2)
        context.insert(user)
        game.trackedBy = user
        let completionDate = Date(timeIntervalSince1970: 2_000)

        // Include multiple active shifts for one player to verify corrupt legacy
        // state is fully closed rather than only closing `currentShift`.
        let first = Shift(shiftNumber: 1, personGameStats: players[0])
        let duplicateActive = Shift(shiftNumber: 2, personGameStats: players[0])
        let second = Shift(shiftNumber: 1, personGameStats: players[1])
        context.insert(first)
        context.insert(duplicateActive)
        context.insert(second)
        players[0].shifts = [first, duplicateActive]
        players[1].shifts = [second]
        try context.save()

        var saves = 0
        let result = try game.finalize(
            in: context,
            teamScore: 20,
            opponentScore: 15,
            completedAt: completionDate,
            save: {
                saves += 1
                try context.save()
            }
        )

        XCTAssertEqual(result, .finalized)
        XCTAssertEqual(saves, 1)
        XCTAssertTrue(game.isCompleted)
        XCTAssertEqual(game.completedAt, completionDate)
        XCTAssertTrue([first, duplicateActive, second].allSatisfy { $0.endTime == completionDate })
        XCTAssertTrue([first, duplicateActive, second].allSatisfy {
            $0.endingTeamScore == 20 && $0.endingOpponentScore == 15
        })
        XCTAssertEqual(user.currentStreak, 1)

        XCTAssertEqual(try game.finalize(in: context, save: { saves += 1 }), .alreadyFinalized)
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(user.currentStreak, 1)
    }

    func testFinalizingOlderGameDoesNotRewindTrackerStreak() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let user = User(displayName: "Tracker")
        context.insert(user)
        user.recordGameCompletion(on: Date(timeIntervalSince1970: 200_000))
        try context.save()

        let game = Game(gameDate: Date(timeIntervalSince1970: 100_000), opponent: "Older")
        game.trackedBy = user
        context.insert(game)

        XCTAssertEqual(try game.finalize(in: context), .finalized)
        XCTAssertEqual(user.currentStreak, 1)
        XCTAssertEqual(user.lastGameDate, Date(timeIntervalSince1970: 200_000))
    }

    func testFinalizeFailureRollsBackCompletionShiftsAndTrackerStreak() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let user = User(displayName: "Tracker")
        let (game, players) = insertGameGraph(in: context)
        context.insert(user)
        game.trackedBy = user
        let shift = players[0].startNewShift()
        context.insert(shift)
        try context.save()

        XCTAssertThrowsError(try game.finalize(
            in: context,
            teamScore: 10,
            opponentScore: 9,
            save: { throw TestFailure.injectedSaveFailure }
        )) { error in
            XCTAssertEqual(error as? TestFailure, .injectedSaveFailure)
        }

        XCTAssertFalse(game.isCompleted)
        XCTAssertNil(game.completedAt)
        XCTAssertTrue(shift.isActive)
        XCTAssertNil(shift.endingTeamScore)
        XCTAssertNil(shift.endingOpponentScore)
        XCTAssertEqual(user.currentStreak, 0)
        XCTAssertNil(user.lastGameDate)
    }

    func testMigrationConvertsMultiplePlayersReconcilesMirrorsAndIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (game, players) = insertGameGraph(in: context, playerCount: 2)
        let firstShift = players[0].startNewShift()
        let secondShift = players[1].startNewShift()
        context.insert(firstShift)
        context.insert(secondShift)

        let direct = Stat(statName: "2PT", pointValue: 2, made: 3, missed: 1, game: game)
        context.insert(direct)
        game.stats = [direct]
        let firstLegacy = ShiftStat(
            statName: "2PT",
            pointValue: 2,
            made: 1,
            missed: 1,
            shift: firstShift
        )
        let secondLegacy = ShiftStat(
            statName: "2PT",
            pointValue: 2,
            made: 2,
            missed: 0,
            shift: secondShift
        )
        context.insert(firstLegacy)
        context.insert(secondLegacy)
        firstShift.stats = [firstLegacy]
        secondShift.stats = [secondLegacy]
        try context.save()

        let firstReport = try StatAttributionMigration.migrateLegacyShiftStats(in: context)
        XCTAssertEqual(firstReport.migratedLegacyStats, 2)
        XCTAssertEqual(firstReport.reconciledMirroredValues, 4)
        XCTAssertEqual(firstShift.totalMade(forName: "2PT"), 1)
        XCTAssertEqual(secondShift.totalMade(forName: "2PT"), 2)
        XCTAssertEqual(players[0].aggregatedMade(forName: "2PT"), 1)
        XCTAssertEqual(players[1].aggregatedMade(forName: "2PT"), 2)
        XCTAssertEqual(game.totalMade(forName: "2PT"), 3)
        XCTAssertEqual(game.totalMissed(forName: "2PT"), 1)
        XCTAssertEqual(game.totalPoints, 6)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ShiftStat>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Stat>()), 2)

        let idsAfterFirstRun = Set(try context.fetch(FetchDescriptor<Stat>()).map(\.id))
        let secondReport = try StatAttributionMigration.migrateLegacyShiftStats(in: context)
        let idsAfterSecondRun = Set(try context.fetch(FetchDescriptor<Stat>()).map(\.id))
        XCTAssertEqual(secondReport, StatAttributionMigrationReport())
        XCTAssertEqual(idsAfterSecondRun, idsAfterFirstRun)
        XCTAssertEqual(game.totalMade(forName: "2PT"), 3)
        XCTAssertEqual(game.totalPoints, 6)
    }

    func testMigrationPreservesAmbiguousDirectAndShiftOnlyCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (game, players) = insertGameGraph(in: context)
        let shift = players[0].startNewShift()
        context.insert(shift)

        // These may come from independent legacy writers. Because they are not
        // exact mirrors, migration must preserve both rather than guess.
        let direct = Stat(statName: "2PT", pointValue: 2, made: 3, game: game)
        let legacy = ShiftStat(statName: "2PT", pointValue: 2, made: 2, shift: shift)
        context.insert(direct)
        context.insert(legacy)
        game.stats = [direct]
        shift.stats = [legacy]
        try context.save()

        let report = try StatAttributionMigration.migrateLegacyShiftStats(in: context)

        XCTAssertEqual(report.migratedLegacyStats, 1)
        XCTAssertEqual(report.reconciledMirroredValues, 0)
        XCTAssertEqual(report.preservedAmbiguousGameAggregates, 1)
        XCTAssertEqual(game.totalMade(forName: "2PT"), 5)
        XCTAssertEqual(game.totalPoints, 10)
        XCTAssertEqual(players[0].aggregatedMade(forName: "2PT"), 2)
    }

    func testMigrationBackfillsPersonOnlyCanonicalStatGameLink() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (game, players) = insertGameGraph(in: context)
        let personOnly = Stat(
            statName: "STL",
            count: 2,
            personGameStats: players[0]
        )
        context.insert(personOnly)
        players[0].stats = [personOnly]
        try context.save()

        XCTAssertNil(personOnly.game)
        let report = try StatAttributionMigration.migrateLegacyShiftStats(in: context)
        XCTAssertEqual(report.linkedExistingStatsToGames, 1)
        XCTAssertTrue(personOnly.game === game)
        XCTAssertEqual(game.totalCount(forName: "STL"), 2)
        XCTAssertEqual(players[0].totalSteals, 2)
    }
}
