import Foundation
import SwiftData

enum StatAttributionError: LocalizedError, Equatable {
    case personBelongsToDifferentGame
    case shiftRequiresPerson
    case shiftBelongsToDifferentPerson

    var errorDescription: String? {
        switch self {
        case .personBelongsToDifferentGame:
            return "The selected player stats belong to another game."
        case .shiftRequiresPerson:
            return "A shift stat must be attributed to a player."
        case .shiftBelongsToDifferentPerson:
            return "The selected shift belongs to another player."
        }
    }
}

enum GameFinalizationResult: Equatable {
    case finalized
    case alreadyFinalized
}

@Model
final class Game {
    var id: UUID = UUID()
    var gameDate: Date = Date()
    var opponent: String = ""
    var location: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()

    var sport: Sport?
    var trackedBy: User?
    var team: Team?

    var lockedByUserID: String?
    var lockExpiresAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PersonGameStats.game)
    var personStats: [PersonGameStats]? = []

    /// All canonical game events. Player and shift attribution live on the same Stat row.
    @Relationship(deleteRule: .cascade, inverse: \Stat.game)
    var stats: [Stat]? = []

    var isLocked: Bool {
        guard let expiresAt = lockExpiresAt else { return false }
        return expiresAt > Date()
    }

    /// Canonical records visible from any inverse relationship, de-duplicated by stable ID.
    var canonicalStats: [Stat] {
        var result: [Stat] = []
        var seen = Set<UUID>()

        func append(_ records: [Stat]) {
            for record in records
            where record.game?.id == id && seen.insert(record.id).inserted {
                result.append(record)
            }
        }

        append(stats ?? [])
        for personGameStats in personStats ?? [] {
            append(personGameStats.stats ?? [])
            for shift in personGameStats.shifts ?? [] {
                append(shift.statRecords ?? [])
            }
        }
        return result
    }

    var totalPoints: Int {
        canonicalStats.reduce(0) { $0 + $1.points }
    }

    func stat(named name: String) -> Stat? {
        canonicalStats.first { $0.statName == name }
    }

    func stats(named name: String) -> [Stat] {
        canonicalStats.filter { $0.statName == name }
    }

    func totalMade(forName name: String) -> Int {
        stats(named: name).reduce(0) { $0 + $1.made }
    }

    func totalMissed(forName name: String) -> Int {
        stats(named: name).reduce(0) { $0 + $1.missed }
    }

    func totalCount(forName name: String) -> Int {
        stats(named: name).reduce(0) { $0 + $1.count }
    }

    /// Compact value shown on player game lists. Uses goals for soccer and the
    /// primary stat for individual sports instead of basketball points.
    var listSummaryValue: Int {
        if sport?.name == "Soccer" { return totalCount(forName: "GOL") }
        if sport?.name == "Basketball" { return totalPoints }
        if let value = SportCatalog.primaryScoreValue(
            sportName: sport?.name,
            points: totalPoints,
            made: { totalMade(forName: $0) },
            count: { totalCount(forName: $0) }
        ) {
            return value
        }
        if sport?.isTeamSport == false, let definition = sport?.sortedStatDefinitions.first {
            return definition.hasMadeAndMissed
                ? totalMade(forName: definition.shortName)
                : totalCount(forName: definition.shortName)
        }
        return totalPoints
    }

    var listSummaryLabel: String {
        if sport?.name == "Soccer" { return "goals" }
        if sport?.name == "Basketball" { return "points" }
        if sport?.isTeamSport == false, let definition = sport?.sortedStatDefinitions.first {
            return definition.shortName.lowercased()
        }
        if let profile = SportCatalog.profile(named: sport?.name) {
            return profile.primaryScoreLabel.lowercased()
        }
        return "points"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: gameDate)
    }

    init(
        gameDate: Date = Date(),
        opponent: String = "",
        location: String = "",
        notes: String = "",
        isCompleted: Bool = false,
        sport: Sport? = nil,
        trackedBy: User? = nil
    ) {
        self.id = UUID()
        self.gameDate = gameDate
        self.opponent = opponent
        self.location = location
        self.notes = notes
        self.isCompleted = isCompleted
        self.sport = sport
        self.trackedBy = trackedBy
        self.createdAt = Date()
    }

    // MARK: - Canonical stat mutation

    @discardableResult
    func recordStat(
        named name: String,
        pointValue: Int,
        mutation: StatMutation,
        personGameStats: PersonGameStats? = nil,
        shift: Shift? = nil,
        in context: ModelContext
    ) throws -> Stat {
        try validateAttribution(personGameStats: personGameStats, shift: shift)
        let stat = statRecord(named: name, personGameStats: personGameStats, shift: shift)
            ?? makeStatRecord(
                named: name,
                pointValue: pointValue,
                personGameStats: personGameStats,
                shift: shift,
                in: context
            )
        stat.pointValue = pointValue
        stat.apply(mutation)
        return stat
    }

    @discardableResult
    func undoStat(
        named name: String,
        mutation: StatMutation,
        personGameStats: PersonGameStats? = nil,
        shift: Shift? = nil
    ) throws -> Bool {
        try validateAttribution(personGameStats: personGameStats, shift: shift)
        guard let stat = statRecord(named: name, personGameStats: personGameStats, shift: shift) else {
            return false
        }
        return stat.apply(mutation, delta: -1)
    }

    func statRecord(
        named name: String,
        personGameStats: PersonGameStats?,
        shift: Shift?
    ) -> Stat? {
        canonicalStats.first {
            $0.statName == name &&
            $0.personGameStats?.id == personGameStats?.id &&
            $0.shift?.id == shift?.id
        }
    }

    private func makeStatRecord(
        named name: String,
        pointValue: Int,
        personGameStats: PersonGameStats?,
        shift: Shift?,
        in context: ModelContext
    ) -> Stat {
        let stat = Stat(
            statName: name,
            pointValue: pointValue,
            personGameStats: personGameStats,
            game: self,
            shift: shift
        )
        context.insert(stat)

        if stats == nil { stats = [] }
        if stats?.contains(where: { $0.id == stat.id }) == false { stats?.append(stat) }

        if let personGameStats {
            if personGameStats.stats == nil { personGameStats.stats = [] }
            if personGameStats.stats?.contains(where: { $0.id == stat.id }) == false {
                personGameStats.stats?.append(stat)
            }
        }

        if let shift {
            if shift.statRecords == nil { shift.statRecords = [] }
            if shift.statRecords?.contains(where: { $0.id == stat.id }) == false {
                shift.statRecords?.append(stat)
            }
        }
        return stat
    }

    private func validateAttribution(
        personGameStats: PersonGameStats?,
        shift: Shift?
    ) throws {
        if let personGameStats, personGameStats.game?.id != id {
            throw StatAttributionError.personBelongsToDifferentGame
        }
        if shift != nil && personGameStats == nil {
            throw StatAttributionError.shiftRequiresPerson
        }
        if let shift, shift.personGameStats?.id != personGameStats?.id {
            throw StatAttributionError.shiftBelongsToDifferentPerson
        }
    }

    // MARK: - Finalization transaction

    /// Finalizes at most once. All model mutations are persisted in one save and rolled
    /// back together if persistence fails.
    @discardableResult
    func finalize(
        in context: ModelContext,
        teamScore: Int? = nil,
        opponentScore: Int? = nil,
        completedAt date: Date = Date(),
        save: (() throws -> Void)? = nil
    ) throws -> GameFinalizationResult {
        guard !isCompleted else { return .alreadyFinalized }

        let activeShifts = (personStats ?? []).flatMap { $0.shifts ?? [] }.filter(\.isActive)
        let shiftSnapshots = activeShifts.map {
            (shift: $0, endTime: $0.endTime, teamScore: $0.endingTeamScore, opponentScore: $0.endingOpponentScore)
        }
        let completionSnapshot = (isCompleted: isCompleted, completedAt: completedAt)

        for shift in activeShifts {
            shift.endShift(
                teamScore: teamScore,
                opponentScore: opponentScore,
                at: date
            )
        }
        isCompleted = true
        completedAt = date

        do {
            if let save {
                try save()
            } else {
                try context.save()
            }
            return .finalized
        } catch {
            context.rollback()

            // SwiftData rollback restores the backing transaction, but registered
            // model objects can retain their mutated in-memory values. Restore the
            // snapshots too so the UI can safely retry without showing a false final.
            isCompleted = completionSnapshot.isCompleted
            completedAt = completionSnapshot.completedAt
            for snapshot in shiftSnapshots {
                snapshot.shift.endTime = snapshot.endTime
                snapshot.shift.endingTeamScore = snapshot.teamScore
                snapshot.shift.endingOpponentScore = snapshot.opponentScore
            }
            throw error
        }
    }
}
