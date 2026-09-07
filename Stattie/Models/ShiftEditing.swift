import Foundation
import SwiftData

/// Value drafts keep Cancel and failed saves from partially changing a game's history.
struct ShiftDetails: Equatable {
    var startTime: Date
    var endTime: Date?
    var positionRawValue: String
    var startingTeamScore: Int
    var startingOpponentScore: Int
    var endingTeamScore: Int?
    var endingOpponentScore: Int?

    init(_ shift: Shift) {
        startTime = shift.startTime
        endTime = shift.endTime
        positionRawValue = shift.positionRawValue
        startingTeamScore = shift.startingTeamScore
        startingOpponentScore = shift.startingOpponentScore
        endingTeamScore = shift.endingTeamScore
        endingOpponentScore = shift.endingOpponentScore
    }

    func apply(to shift: Shift) {
        shift.startTime = startTime
        shift.endTime = endTime
        shift.positionRawValue = positionRawValue
        shift.startingTeamScore = startingTeamScore
        shift.startingOpponentScore = startingOpponentScore
        shift.endingTeamScore = endingTeamScore
        shift.endingOpponentScore = endingOpponentScore
    }

    var plusMinus: Int? {
        guard let endingTeamScore, let endingOpponentScore else { return nil }
        return endingTeamScore - startingTeamScore - endingOpponentScore + startingOpponentScore
    }
}

struct ShiftStatCounts: Equatable {
    var made = 0
    var missed = 0
    var count = 0

    init(records: [Stat] = []) {
        for record in records {
            made += record.made
            missed += record.missed
            count += record.count
        }
    }

    var isEmpty: Bool { made == 0 && missed == 0 && count == 0 }
    var isValid: Bool { made >= 0 && missed >= 0 && count >= 0 }
}

struct EditableShiftStat: Identifiable {
    let id: String
    let title: String
    let pointValue: Int
    let hasMadeAndMissed: Bool
    var values: ShiftStatCounts
}

enum ShiftEditingError: LocalizedError {
    case unavailable, invalidTime, invalidScore, invalidStats, changedElsewhere

    var errorDescription: String? {
        switch self {
        case .unavailable: "This shift is no longer available in this game."
        case .invalidTime: "The shift must end at or after its start time."
        case .invalidScore: "Scores cannot be negative."
        case .invalidStats: "Stat values cannot be negative."
        case .changedElsewhere: "This shift changed while you were editing. Reopen it to review the latest values."
        }
    }
}

struct ShiftEditDraft {
    var details: ShiftDetails
    var stats: [EditableShiftStat]
    private let originalDetails: ShiftDetails
    private let originalTotals: [String: ShiftStatCounts]

    init(shift: Shift) {
        details = ShiftDetails(shift)
        originalDetails = details
        let records = Dictionary(grouping: shift.canonicalStats, by: \.statName)
        originalTotals = records.mapValues { ShiftStatCounts(records: $0) }
        var rows: [EditableShiftStat] = []
        var names = Set<String>()
        // All sport definitions remain editable, even when the recorded role would
        // hide them during live tracking. Include legacy/custom recorded stats too.
        for definition in shift.personGameStats?.game?.sport?.sortedStatDefinitions ?? [] {
            guard names.insert(definition.shortName).inserted else { continue }
            rows.append(EditableShiftStat(
                id: definition.shortName, title: definition.name,
                pointValue: definition.pointValue, hasMadeAndMissed: definition.hasMadeAndMissed,
                values: originalTotals[definition.shortName] ?? ShiftStatCounts()
            ))
        }
        for spec in SportCatalog.profile(named: shift.personGameStats?.game?.sport?.name)?.stats ?? [] {
            guard names.insert(spec.shortName).inserted else { continue }
            rows.append(EditableShiftStat(
                id: spec.shortName, title: spec.name, pointValue: spec.pointValue,
                hasMadeAndMissed: spec.hasMadeAndMissed,
                values: originalTotals[spec.shortName] ?? ShiftStatCounts()
            ))
        }
        for name in records.keys.sorted() {
            guard names.insert(name).inserted, let record = records[name]?.first else { continue }
            let values = originalTotals[name] ?? ShiftStatCounts()
            rows.append(EditableShiftStat(
                id: name, title: record.definition?.name ?? name, pointValue: record.pointValue,
                hasMadeAndMissed: record.definition?.hasMadeAndMissed == true || values.made > 0 || values.missed > 0,
                values: values
            ))
        }
        stats = rows
    }

    @MainActor
    func save(to shift: Shift, in context: ModelContext, save: (() throws -> Void)? = nil) throws {
        guard let player = shift.personGameStats, let game = player.game else { throw ShiftEditingError.unavailable }
        if let endTime = details.endTime, endTime < details.startTime { throw ShiftEditingError.invalidTime }
        guard [details.startingTeamScore, details.startingOpponentScore,
               details.endingTeamScore ?? 0, details.endingOpponentScore ?? 0].allSatisfy({ $0 >= 0 }) else {
            throw ShiftEditingError.invalidScore
        }
        guard stats.allSatisfy({ $0.values.isValid }) else { throw ShiftEditingError.invalidStats }
        let records = shift.canonicalStats
        let currentTotals = Dictionary(grouping: records, by: \.statName).mapValues { ShiftStatCounts(records: $0) }
        guard ShiftDetails(shift) == originalDetails, currentTotals == originalTotals else {
            throw ShiftEditingError.changedElsewhere
        }
        let previousRows = records.map { ($0, $0.made, $0.missed, $0.count) }
        let previousShiftStats = shift.statRecords
        let previousPlayerStats = player.stats
        let previousGameStats = game.stats
        do {
            details.apply(to: shift)
            for edit in stats where edit.values != (originalTotals[edit.id] ?? ShiftStatCounts()) {
                var matching = records.filter { $0.statName == edit.id }
                if matching.isEmpty, !edit.values.isEmpty {
                    let definition = game.sport?.statDefinitions?.first { $0.shortName == edit.id }
                    let stat = Stat(statName: edit.id, pointValue: edit.pointValue, definition: definition,
                                    personGameStats: player, game: game, shift: shift)
                    context.insert(stat)
                    if !(shift.statRecords ?? []).contains(where: { $0.id == stat.id }) {
                        shift.statRecords = (shift.statRecords ?? []) + [stat]
                    }
                    if !(player.stats ?? []).contains(where: { $0.id == stat.id }) {
                        player.stats = (player.stats ?? []) + [stat]
                    }
                    if !(game.stats ?? []).contains(where: { $0.id == stat.id }) {
                        game.stats = (game.stats ?? []) + [stat]
                    }
                    matching = [stat]
                }
                Self.reconcile(edit.values.made, keyPath: \.made, records: matching)
                Self.reconcile(edit.values.missed, keyPath: \.missed, records: matching)
                Self.reconcile(edit.values.count, keyPath: \.count, records: matching)
            }
            if let save { try save() } else { try context.save() }
        } catch {
            context.rollback()
            originalDetails.apply(to: shift)
            shift.statRecords = previousShiftStats
            player.stats = previousPlayerStats
            game.stats = previousGameStats
            for (record, made, missed, count) in previousRows {
                record.made = made
                record.missed = missed
                record.count = count
            }
            throw error
        }
    }

    /// Reconcile the displayed total across distinct rows without discarding their
    /// identity, attribution or timestamps (including rows imported from iCloud).
    private static func reconcile(_ total: Int, keyPath: ReferenceWritableKeyPath<Stat, Int>, records: [Stat]) {
        let previous = records.reduce(0) { $0 + $1[keyPath: keyPath] }
        if total >= previous {
            if let first = records.first { first[keyPath: keyPath] += total - previous }
        } else {
            var remaining = previous - total
            for record in records.reversed() {
                let decrement = min(record[keyPath: keyPath], remaining)
                record[keyPath: keyPath] -= decrement
                remaining -= decrement
            }
        }
    }
}

extension PersonGameStats {
    /// A live role change creates a boundary, preserving the previous role's time
    /// and stats. History corrections use ShiftEditDraft instead.
    @MainActor
    @discardableResult
    func changePosition(
        to position: SoccerPosition, teamScore: Int, opponentScore: Int,
        at date: Date = Date(), in context: ModelContext, save: (() throws -> Void)? = nil
    ) throws -> Shift {
        guard let active = currentShift, game?.isCompleted == false else { throw ShiftEditingError.unavailable }
        guard date >= active.startTime else { throw ShiftEditingError.invalidTime }
        guard teamScore >= 0, opponentScore >= 0 else { throw ShiftEditingError.invalidScore }
        if active.recordedPosition == position { return active }
        let previousDetails = ShiftDetails(active)
        let previousShifts = shifts
        do {
            active.endShift(teamScore: teamScore, opponentScore: opponentScore, at: date)
            let next = startNewShift(teamScore: teamScore, opponentScore: opponentScore, position: position)
            next.startTime = date
            context.insert(next)
            if let save { try save() } else { try context.save() }
            return next
        } catch {
            context.rollback()
            previousDetails.apply(to: active)
            shifts = previousShifts
            throw error
        }
    }
}
