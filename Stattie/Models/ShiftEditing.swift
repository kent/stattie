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

extension ShiftDetails {
    init(_ shift: Shift) {
        self.init(
            startTime: shift.startTime, endTime: shift.endTime, positionRawValue: shift.positionRawValue,
            startingTeamScore: shift.startingTeamScore, startingOpponentScore: shift.startingOpponentScore,
            endingTeamScore: shift.endingTeamScore, endingOpponentScore: shift.endingOpponentScore
        )
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
        stats = Self.rows(game: shift.personGameStats?.game, records: records, totals: originalTotals)
    }

    /// A completed shift continuing from the player's latest one, or from kickoff at 0-0.
    init(newShiftFor player: PersonGameStats) {
        let game = player.game
        let previous = player.completedShifts.last
        let start = previous?.endTime ?? game?.gameDate ?? Date()
        let team = previous.map { $0.endingTeamScore ?? $0.startingTeamScore } ?? 0
        let opponent = previous.map { $0.endingOpponentScore ?? $0.startingOpponentScore } ?? 0
        let position = previous?.recordedPosition
            ?? player.person?.positionAssignments(for: game).startingPosition(for: game?.sport?.name)
        details = ShiftDetails(
            startTime: start, endTime: start, positionRawValue: position?.rawValue ?? "",
            startingTeamScore: team, startingOpponentScore: opponent,
            endingTeamScore: team, endingOpponentScore: opponent
        )
        originalDetails = details
        originalTotals = [:]
        stats = Self.rows(game: game, records: [:], totals: [:])
    }

    var hasChanges: Bool {
        details != originalDetails || stats.contains { $0.values != (originalTotals[$0.id] ?? ShiftStatCounts()) }
    }

    /// Applies one stat-board tap (or undo, with a negative delta) to the draft only.
    @discardableResult
    mutating func apply(_ mutation: StatMutation, named name: String, pointValue: Int, delta: Int = 1) -> Bool {
        let index: Int
        if let existing = stats.firstIndex(where: { $0.id == name }) {
            index = existing
        } else {
            guard delta > 0 else { return false }
            stats.append(EditableShiftStat(
                id: name, title: name, pointValue: pointValue,
                hasMadeAndMissed: mutation != .count, values: ShiftStatCounts()
            ))
            index = stats.count - 1
        }
        let keyPath: WritableKeyPath<ShiftStatCounts, Int> = switch mutation {
        case .made: \.made
        case .missed: \.missed
        case .count: \.count
        }
        let value = stats[index].values[keyPath: keyPath] + delta
        guard value >= 0 else { return false }
        stats[index].values[keyPath: keyPath] = value
        return true
    }

    @MainActor
    func save(to shift: Shift, in context: ModelContext, save: (() throws -> Void)? = nil) throws {
        guard let player = shift.personGameStats, let game = player.game else { throw ShiftEditingError.unavailable }
        try validate()
        let records = shift.canonicalStats
        let currentTotals = Dictionary(grouping: records, by: \.statName).mapValues { ShiftStatCounts(records: $0) }
        guard ShiftDetails(shift) == originalDetails, currentTotals == originalTotals else {
            throw ShiftEditingError.changedElsewhere
        }
        let previousRows = records.map { ($0, $0.made, $0.missed, $0.count) }
        let previousNumbers = (player.shifts ?? []).map { ($0, $0.shiftNumber) }
        let previousShiftStats = shift.statRecords
        let previousPlayerStats = player.stats
        let previousGameStats = game.stats
        do {
            details.apply(to: shift)
            if details.startTime != originalDetails.startTime { player.renumberShifts() }
            writeStats(to: shift, player: player, game: game, records: records, in: context)
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
            for (shift, number) in previousNumbers { shift.shiftNumber = number }
            throw error
        }
    }

    /// Inserts the draft as a new shift for `player`, numbered chronologically.
    @MainActor
    @discardableResult
    func create(for player: PersonGameStats, in context: ModelContext, save: (() throws -> Void)? = nil) throws -> Shift {
        guard let game = player.game else { throw ShiftEditingError.unavailable }
        try validate()
        let previousShifts = player.shifts
        let previousNumbers = (player.shifts ?? []).map { ($0, $0.shiftNumber) }
        let previousPlayerStats = player.stats
        let previousGameStats = game.stats
        let shift = Shift(personGameStats: player)
        do {
            details.apply(to: shift)
            context.insert(shift)
            if !(player.shifts ?? []).contains(where: { $0.id == shift.id }) {
                player.shifts = (player.shifts ?? []) + [shift]
            }
            player.renumberShifts()
            writeStats(to: shift, player: player, game: game, records: [], in: context)
            if let save { try save() } else { try context.save() }
            return shift
        } catch {
            context.rollback()
            player.shifts = previousShifts
            player.stats = previousPlayerStats
            game.stats = previousGameStats
            for (shift, number) in previousNumbers { shift.shiftNumber = number }
            throw error
        }
    }

    private func validate() throws {
        if let endTime = details.endTime, endTime < details.startTime { throw ShiftEditingError.invalidTime }
        guard [details.startingTeamScore, details.startingOpponentScore,
               details.endingTeamScore ?? 0, details.endingOpponentScore ?? 0].allSatisfy({ $0 >= 0 }) else {
            throw ShiftEditingError.invalidScore
        }
        guard stats.allSatisfy({ $0.values.isValid }) else { throw ShiftEditingError.invalidStats }
    }

    private func writeStats(to shift: Shift, player: PersonGameStats, game: Game, records: [Stat], in context: ModelContext) {
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
    }

    /// All sport definitions remain editable, even when the recorded role would
    /// hide them during live tracking. Legacy/custom recorded stats are included too.
    private static func rows(game: Game?, records: [String: [Stat]], totals: [String: ShiftStatCounts]) -> [EditableShiftStat] {
        var rows: [EditableShiftStat] = []
        var names = Set<String>()
        for definition in game?.sport?.sortedStatDefinitions ?? [] {
            guard names.insert(definition.shortName).inserted else { continue }
            rows.append(EditableShiftStat(
                id: definition.shortName, title: definition.name,
                pointValue: definition.pointValue, hasMadeAndMissed: definition.hasMadeAndMissed,
                values: totals[definition.shortName] ?? ShiftStatCounts()
            ))
        }
        for spec in SportCatalog.profile(named: game?.sport?.name)?.stats ?? [] {
            guard names.insert(spec.shortName).inserted else { continue }
            rows.append(EditableShiftStat(
                id: spec.shortName, title: spec.name, pointValue: spec.pointValue,
                hasMadeAndMissed: spec.hasMadeAndMissed,
                values: totals[spec.shortName] ?? ShiftStatCounts()
            ))
        }
        for name in records.keys.sorted() {
            guard names.insert(name).inserted, let record = records[name]?.first else { continue }
            let values = totals[name] ?? ShiftStatCounts()
            rows.append(EditableShiftStat(
                id: name, title: record.definition?.name ?? name, pointValue: record.pointValue,
                hasMadeAndMissed: record.definition?.hasMadeAndMissed == true || values.made > 0 || values.missed > 0,
                values: values
            ))
        }
        return rows
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

extension ShiftEditDraft: StatTotals {
    var totalPoints: Int { stats.reduce(0) { $0 + $1.pointValue * $1.values.made } }
    func totalMade(forName name: String) -> Int { counts(name).made }
    func totalMissed(forName name: String) -> Int { counts(name).missed }
    func totalCount(forName name: String) -> Int { counts(name).count }

    private func counts(_ name: String) -> ShiftStatCounts {
        stats.first { $0.id == name }?.values ?? ShiftStatCounts()
    }
}

/// A team/opponent score pair.
struct GameScore: Equatable {
    var team: Int
    var opponent: Int
}

extension Game {
    /// Players whose shifts can be tracked, in jersey then name order.
    var shiftPlayers: [PersonGameStats] {
        (personStats ?? []).filter { $0.person != nil }.sorted { lhs, rhs in
            let leftJersey = lhs.person?.jerseyNumber ?? Int.max
            let rightJersey = rhs.person?.jerseyNumber ?? Int.max
            if leftJersey != rightJersey { return leftJersey < rightJersey }
            let leftName = lhs.person?.fullName ?? ""
            let rightName = rhs.person?.fullName ?? ""
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
    }

    var hasActiveShifts: Bool {
        (personStats ?? []).contains { $0.currentShift != nil }
    }

    /// The most recent score recorded at any player's shift boundary.
    var latestShiftScore: GameScore {
        let marks = (personStats ?? []).flatMap { $0.shifts ?? [] }.flatMap { shift -> [(Date, GameScore)] in
            var boundaries = [(shift.startTime, GameScore(team: shift.startingTeamScore, opponent: shift.startingOpponentScore))]
            if let end = shift.endTime, let team = shift.endingTeamScore, let opponent = shift.endingOpponentScore {
                boundaries.append((end, GameScore(team: team, opponent: opponent)))
            }
            return boundaries
        }
        return marks.max { $0.0 < $1.0 }?.1 ?? GameScore(team: 0, opponent: 0)
    }
}

extension PersonGameStats {
    var orderedShifts: [Shift] {
        (shifts ?? []).sorted { ($0.shiftNumber, $0.startTime) < ($1.shiftNumber, $1.startTime) }
    }

    /// Numbers shifts 1...n by start time so corrections keep history chronological.
    func renumberShifts() {
        let ordered = (shifts ?? []).sorted { ($0.startTime, $0.createdAt) < ($1.startTime, $1.createdAt) }
        for (index, shift) in ordered.enumerated() where shift.shiftNumber != index + 1 {
            shift.shiftNumber = index + 1
        }
    }

    /// Removes a shift and its stats from every total in one transaction.
    @MainActor
    func deleteShift(_ shift: Shift, in context: ModelContext, save: (() throws -> Void)? = nil) throws {
        guard shift.personGameStats?.id == id else { throw ShiftEditingError.unavailable }
        let records = shift.statRecords ?? []
        let recordIDs = Set(records.map(\.id))
        let previousShifts = shifts
        let previousNumbers = (shifts ?? []).map { ($0, $0.shiftNumber) }
        let previousPlayerStats = stats
        let previousGameStats = game?.stats
        do {
            shifts?.removeAll { $0.id == shift.id }
            stats?.removeAll { recordIDs.contains($0.id) }
            game?.stats?.removeAll { recordIDs.contains($0.id) }
            for record in records { context.delete(record) }
            context.delete(shift)
            renumberShifts()
            if let save { try save() } else { try context.save() }
        } catch {
            context.rollback()
            shifts = previousShifts
            shift.statRecords = records
            stats = previousPlayerStats
            game?.stats = previousGameStats
            for (shift, number) in previousNumbers { shift.shiftNumber = number }
            throw error
        }
    }

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
