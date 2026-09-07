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
        let shift = player.startNewShift(position: .defender)
        context.insert(shift)
        shift.endShift(teamScore: 1, opponentScore: 0, at: shift.startTime.addingTimeInterval(120))
        try context.save()
        return (container, game, player, shift)
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
}
