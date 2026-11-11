import XCTest
import SwiftData
@testable import Stattie

@MainActor
final class ShiftEditingTests: XCTestCase {
    private func fixture() throws -> (ModelContainer, Game, PersonGameStats, Shift) {
        let schema = SharedModelContainer.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ])
        let context = container.mainContext
        let sport = Sport(name: "Soccer")
        let game = Game(isCompleted: true, sport: sport)
        let player = PersonGameStats(person: Person(firstName: "Emma"), game: game)
        context.insert(sport)
        context.insert(game)
        context.insert(player)
        link(player, to: game)
        let shift = player.startNewShift(position: .defender)
        context.insert(shift)
        shift.endShift(teamScore: 1, opponentScore: 0, at: shift.startTime.addingTimeInterval(120))
        try context.save()
        return (container, game, player, shift)
    }

    private func link(_ player: PersonGameStats, to game: Game) {
        if !(game.personStats ?? []).contains(where: { $0.id == player.id }) {
            game.personStats = (game.personStats ?? []) + [player]
        }
    }

    private func addStat(_ name: String, count: Int, shift: Shift, context: ModelContext) -> Stat {
        let stat = Stat(statName: name, count: count, personGameStats: shift.personGameStats,
                        game: shift.personGameStats?.game, shift: shift)
        context.insert(stat)
        // Match production's canonical relation shape, retaining distinct row IDs.
        if !(shift.statRecords ?? []).contains(where: { $0.id == stat.id }) {
            shift.statRecords = (shift.statRecords ?? []) + [stat]
        }
        return stat
    }

    func testDraftIncludesSportStatsAndLegacyStatsWithoutChangingTheStore() throws {
        let (container, _, _, shift) = try fixture()
        let record = addStat("CUSTOM", count: 3, shift: shift, context: container.mainContext)
        try container.mainContext.save()
        let original = ShiftDetails(shift)
        var draft = ShiftEditDraft(shift: shift)
        XCTAssertTrue(draft.stats.contains { $0.id == "SAV" })
        XCTAssertTrue(draft.stats.contains { $0.id == "SOT" && $0.hasMadeAndMissed })
        XCTAssertFalse(draft.stats.contains { $0.id == "2PT" })
        let index = try XCTUnwrap(draft.stats.firstIndex { $0.id == "CUSTOM" })
        draft.stats[index].values.count = 9
        draft.details.positionRawValue = SoccerPosition.goalkeeper.rawValue
        draft.details.endTime = shift.startTime.addingTimeInterval(240)
        XCTAssertEqual(ShiftDetails(shift), original)
        XCTAssertEqual(record.count, 3)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testCompletedShiftReconciliationUpdatesGameAndPositionTotalsExactlyOnce() throws {
        let (container, game, player, shift) = try fixture()
        let context = container.mainContext
        let first = addStat("SAV", count: 2, shift: shift, context: context)
        let second = addStat("SAV", count: 3, shift: shift, context: context)
        let custom = addStat("CUSTOM", count: 4, shift: shift, context: context)
        try context.save()
        let ids = Set([first.id, second.id, custom.id])
        var draft = ShiftEditDraft(shift: shift)
        let saves = try XCTUnwrap(draft.stats.firstIndex { $0.id == "SAV" })
        XCTAssertEqual(draft.stats[saves].values.count, 5)
        draft.stats[saves].values.count = 7
        let shots = try XCTUnwrap(draft.stats.firstIndex { $0.id == "SOT" })
        draft.stats[shots].values.made = 2
        draft.stats[shots].values.missed = 1
        draft.details.positionRawValue = SoccerPosition.goalkeeper.rawValue
        draft.details.startTime = shift.startTime.addingTimeInterval(-30)
        draft.details.endTime = draft.details.startTime.addingTimeInterval(255)
        draft.details.startingTeamScore = 1
        draft.details.startingOpponentScore = 1
        draft.details.endingTeamScore = 3
        draft.details.endingOpponentScore = 2
        try draft.save(to: shift, in: context)

        XCTAssertTrue(game.isCompleted)
        XCTAssertEqual(shift.duration, 255)
        XCTAssertEqual(shift.plusMinus, 1)
        XCTAssertEqual(player.totalPlusMinus, 1)
        XCTAssertEqual(shift.totalCount(forName: "SAV"), 7)
        XCTAssertEqual(player.totalCount(forName: "SAV"), 7)
        XCTAssertEqual(game.totalCount(forName: "SAV"), 7)
        XCTAssertEqual(game.totalMade(forName: "SOT"), 2)
        XCTAssertEqual(game.totalMissed(forName: "SOT"), 1)
        XCTAssertEqual(shift.totalCount(forName: "CUSTOM"), 4)
        XCTAssertTrue(ids.isSubset(of: Set(shift.canonicalStats.map(\.id))))
        let totals = try XCTUnwrap(PositionStatAggregator.totals(from: player.shifts ?? []).first)
        XCTAssertEqual(totals.position, .goalkeeper)
        XCTAssertEqual(totals.count(forName: "SAV"), 7)

        var decrease = ShiftEditDraft(shift: shift)
        let savedIndex = try XCTUnwrap(decrease.stats.firstIndex { $0.id == "SAV" })
        decrease.stats[savedIndex].values.count = 1
        try decrease.save(to: shift, in: context)
        XCTAssertEqual(game.totalCount(forName: "SAV"), 1)
        XCTAssertEqual(first.count + second.count, 1)
    }

    func testFailedReconciliationRestoresMetadataCountsAndRelationships() throws {
        let (container, game, player, shift) = try fixture()
        let context = container.mainContext
        let existing = addStat("SAV", count: 2, shift: shift, context: context)
        try context.save()
        let original = ShiftDetails(shift)
        var draft = ShiftEditDraft(shift: shift)
        draft.details.positionRawValue = SoccerPosition.goalkeeper.rawValue
        draft.details.endingTeamScore = 9
        draft.details.endTime = shift.startTime.addingTimeInterval(300)
        let saves = try XCTUnwrap(draft.stats.firstIndex { $0.id == "SAV" })
        draft.stats[saves].values.count = 10
        let shots = try XCTUnwrap(draft.stats.firstIndex { $0.id == "SOT" })
        draft.stats[shots].values.made = 3
        XCTAssertThrowsError(try draft.save(to: shift, in: context, save: { throw CocoaError(.fileWriteUnknown) }))
        XCTAssertEqual(ShiftDetails(shift), original)
        XCTAssertEqual(existing.count, 2)
        XCTAssertEqual(shift.canonicalStats.map(\.id), [existing.id])
        XCTAssertEqual(player.totalCount(forName: "SAV"), 2)
        XCTAssertEqual(game.totalMade(forName: "SOT"), 0)
        // The retained draft can be retried after the storage error is resolved.
        try draft.save(to: shift, in: context)
        XCTAssertEqual(game.totalCount(forName: "SAV"), 10)
        XCTAssertEqual(game.totalMade(forName: "SOT"), 3)
    }

    func testInvalidTimeAndNegativeStatsNeverMutateShift() throws {
        let (container, _, _, shift) = try fixture()
        let original = ShiftDetails(shift)
        var draft = ShiftEditDraft(shift: shift)
        draft.details.endTime = shift.startTime.addingTimeInterval(-1)
        XCTAssertThrowsError(try draft.save(to: shift, in: container.mainContext))
        XCTAssertEqual(ShiftDetails(shift), original)
        draft.details = original
        draft.stats[0].values.count = -1
        XCTAssertThrowsError(try draft.save(to: shift, in: container.mainContext))
        XCTAssertEqual(ShiftDetails(shift), original)
    }

    func testConcurrentStatChangeIsNotOverwrittenByStaleDraft() throws {
        let (container, _, _, shift) = try fixture()
        let context = container.mainContext
        let record = addStat("SAV", count: 2, shift: shift, context: context)
        try context.save()
        var draft = ShiftEditDraft(shift: shift)
        draft.details.endingTeamScore = 9
        record.count = 4
        try context.save()
        XCTAssertThrowsError(try draft.save(to: shift, in: context))
        XCTAssertEqual(record.count, 4)
        XCTAssertEqual(shift.endingTeamScore, 1)
    }

    func testBoardTapsChangeOnlyTheDraftUntilSaved() throws {
        let (container, game, player, shift) = try fixture()
        var draft = ShiftEditDraft(shift: shift)
        XCTAssertFalse(draft.hasChanges)
        XCTAssertTrue(draft.apply(.count, named: "GOL", pointValue: 0))
        XCTAssertTrue(draft.apply(.count, named: "GOL", pointValue: 0))
        XCTAssertTrue(draft.apply(.count, named: "GOL", pointValue: 0, delta: -1))
        XCTAssertFalse(draft.apply(.missed, named: "SOT", pointValue: 0, delta: -1))
        XCTAssertFalse(draft.apply(.count, named: "UNKNOWN", pointValue: 0, delta: -1))
        XCTAssertTrue(draft.apply(.made, named: "BONUS", pointValue: 2))
        XCTAssertEqual(draft.totalCount(forName: "GOL"), 1)
        XCTAssertEqual(draft.madeString(forName: "BONUS"), "1/1")
        XCTAssertEqual(draft.totalPoints, 2)
        XCTAssertTrue(draft.hasChanges)
        XCTAssertEqual(game.totalCount(forName: "GOL"), 0)
        XCTAssertFalse(container.mainContext.hasChanges)

        try draft.save(to: shift, in: container.mainContext)
        XCTAssertEqual(shift.totalCount(forName: "GOL"), 1)
        XCTAssertEqual(player.totalCount(forName: "GOL"), 1)
        XCTAssertEqual(game.totalCount(forName: "GOL"), 1)
        XCTAssertEqual(game.totalPoints, 2)
    }

    func testCreatingShiftContinuesFromLatestShiftAndRenumbersChronologically() throws {
        let (container, game, player, shift) = try fixture()
        let context = container.mainContext
        var draft = ShiftEditDraft(newShiftFor: player)
        XCTAssertFalse(draft.hasChanges)
        XCTAssertEqual(draft.details.startTime, shift.endTime)
        XCTAssertEqual(draft.details.startingTeamScore, 1)
        XCTAssertEqual(draft.details.endingTeamScore, 1)
        XCTAssertEqual(draft.details.positionRawValue, SoccerPosition.defender.rawValue)

        // A forgotten shift that happened before the recorded one.
        draft.details.startTime = shift.startTime.addingTimeInterval(-300)
        draft.details.endTime = shift.startTime.addingTimeInterval(-60)
        draft.details.startingTeamScore = 0
        draft.details.endingTeamScore = 0
        draft.details.endingOpponentScore = 1
        draft.apply(.count, named: "TKL", pointValue: 0)
        let created = try draft.create(for: player, in: context)

        XCTAssertEqual(player.orderedShifts.map(\.id), [created.id, shift.id])
        XCTAssertEqual(created.shiftNumber, 1)
        XCTAssertEqual(shift.shiftNumber, 2)
        XCTAssertEqual(created.duration, 240)
        XCTAssertEqual(created.plusMinus, -1)
        XCTAssertEqual(player.totalPlusMinus, 0)
        XCTAssertEqual(created.totalCount(forName: "TKL"), 1)
        XCTAssertEqual(game.totalCount(forName: "TKL"), 1)
        XCTAssertFalse(context.hasChanges)
    }

    func testFailedCreateLeavesNoShiftOrStats() throws {
        let (container, game, player, shift) = try fixture()
        var draft = ShiftEditDraft(newShiftFor: player)
        draft.details.startTime = shift.startTime.addingTimeInterval(-300)
        draft.details.endTime = shift.startTime
        draft.apply(.count, named: "TKL", pointValue: 0)
        XCTAssertThrowsError(try draft.create(for: player, in: container.mainContext, save: { throw CocoaError(.fileWriteUnknown) }))
        XCTAssertEqual(player.shifts?.map(\.id), [shift.id])
        XCTAssertEqual(shift.shiftNumber, 1)
        XCTAssertEqual(game.totalCount(forName: "TKL"), 0)

        try draft.create(for: player, in: container.mainContext)
        XCTAssertEqual(player.orderedShifts.count, 2)
        XCTAssertEqual(game.totalCount(forName: "TKL"), 1)
    }

    func testDeletingShiftRemovesItsStatsAndRenumbers() throws {
        let (container, game, player, first) = try fixture()
        let context = container.mainContext
        _ = addStat("SAV", count: 2, shift: first, context: context)
        var draft = ShiftEditDraft(newShiftFor: player)
        draft.details.endTime = draft.details.startTime.addingTimeInterval(90)
        draft.apply(.count, named: "SAV", pointValue: 0)
        let second = try draft.create(for: player, in: context)
        XCTAssertEqual(second.shiftNumber, 2)
        XCTAssertEqual(game.totalCount(forName: "SAV"), 3)

        try player.deleteShift(first, in: context)
        XCTAssertEqual(player.shifts?.map(\.id), [second.id])
        XCTAssertEqual(second.shiftNumber, 1)
        XCTAssertEqual(player.totalCount(forName: "SAV"), 1)
        XCTAssertEqual(game.totalCount(forName: "SAV"), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Stat>()), 1)
    }

    func testFailedDeleteRestoresShiftAndStats() throws {
        let (container, game, player, shift) = try fixture()
        let context = container.mainContext
        let stat = addStat("SAV", count: 2, shift: shift, context: context)
        try context.save()
        XCTAssertThrowsError(try player.deleteShift(shift, in: context, save: { throw CocoaError(.fileWriteUnknown) }))
        XCTAssertEqual(player.shifts?.map(\.id), [shift.id])
        XCTAssertEqual(shift.canonicalStats.map(\.id), [stat.id])
        XCTAssertEqual(game.totalCount(forName: "SAV"), 2)

        try player.deleteShift(shift, in: context)
        XCTAssertTrue(player.shifts?.isEmpty ?? true)
        XCTAssertEqual(game.totalCount(forName: "SAV"), 0)
    }

    func testLatestShiftScoreUsesMostRecentBoundaryAcrossPlayers() throws {
        let (container, game, _, shift) = try fixture()
        let context = container.mainContext
        XCTAssertFalse(game.hasActiveShifts)
        XCTAssertEqual(game.latestShiftScore, GameScore(team: 1, opponent: 0))

        let other = PersonGameStats(person: Person(firstName: "Ava"), game: game)
        context.insert(other)
        link(other, to: game)
        let live = other.startNewShift(teamScore: 2, opponentScore: 3)
        context.insert(live)
        live.startTime = try XCTUnwrap(shift.endTime).addingTimeInterval(60)
        try context.save()

        XCTAssertTrue(game.hasActiveShifts)
        XCTAssertEqual(game.latestShiftScore, GameScore(team: 2, opponent: 3))
        XCTAssertEqual(game.shiftPlayers.count, 2)
    }
}
