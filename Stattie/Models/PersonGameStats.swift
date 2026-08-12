import Foundation
import SwiftData

@Model
final class PersonGameStats {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    var person: Person?
    var game: Game?

    @Relationship(deleteRule: .cascade, inverse: \Stat.personGameStats)
    var stats: [Stat]? = []

    @Relationship(deleteRule: .cascade, inverse: \Shift.personGameStats)
    var shifts: [Shift]? = []

    // MARK: - Current Shift

    var currentShift: Shift? {
        (shifts ?? []).filter { $0.isActive }.max { lhs, rhs in
            if lhs.startTime != rhs.startTime {
                return lhs.startTime < rhs.startTime
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var hasActiveShift: Bool {
        currentShift != nil
    }

    var completedShifts: [Shift] {
        (shifts ?? []).filter { !$0.isActive }.sorted { $0.shiftNumber < $1.shiftNumber }
    }

    var totalShiftTime: TimeInterval {
        (shifts ?? []).reduce(0) { $0 + $1.duration }
    }

    var formattedTotalShiftTime: String {
        let totalSeconds = Int(totalShiftTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Canonical Stat Aggregation

    /// Stats attributed to this player, including shift-scoped records, de-duplicated by ID.
    var canonicalStats: [Stat] {
        var result: [Stat] = []
        var seen = Set<UUID>()
        for stat in stats ?? []
        where stat.personGameStats?.id == id &&
              stat.game?.id == game?.id &&
              seen.insert(stat.id).inserted {
            result.append(stat)
        }
        for shift in shifts ?? [] where shift.personGameStats?.id == id {
            for stat in shift.statRecords ?? []
            where stat.personGameStats?.id == id &&
                  stat.game?.id == game?.id &&
                  stat.shift?.id == shift.id &&
                  seen.insert(stat.id).inserted {
                result.append(stat)
            }
        }
        return result
    }

    var totalPointsFromShifts: Int {
        var seen = Set<UUID>()
        return (shifts ?? []).reduce(0) { total, shift in
            total + shift.canonicalStats
                .filter { seen.insert($0.id).inserted }
                .reduce(0) { $0 + $1.points }
        }
    }

    var totalPoints: Int {
        canonicalStats.reduce(0) { $0 + $1.points }
    }

    var totalRebounds: Int {
        aggregatedCount(forName: "DREB") + aggregatedCount(forName: "OREB")
    }

    var totalSteals: Int {
        aggregatedCount(forName: "STL")
    }

    var totalAssists: Int {
        aggregatedCount(forName: "AST")
    }

    var totalFouls: Int {
        aggregatedCount(forName: "PF")
    }

    init(person: Person? = nil, game: Game? = nil) {
        self.id = UUID()
        self.person = person
        self.game = game
        self.createdAt = Date()
    }

    // MARK: - Plus/Minus Aggregation

    /// Total plus/minus across all completed shifts
    var totalPlusMinus: Int {
        completedShifts.compactMap { $0.plusMinus }.reduce(0, +)
    }

    /// Formatted total plus/minus
    var formattedTotalPlusMinus: String {
        let pm = totalPlusMinus
        if pm > 0 { return "+\(pm)" }
        return "\(pm)"
    }

    // MARK: - Shift Management

    func startNewShift(teamScore: Int = 0, opponentScore: Int = 0) -> Shift {
        if let existing = currentShift {
            return existing
        }

        let shiftNumber = (shifts ?? []).count + 1
        let shift = Shift(
            shiftNumber: shiftNumber,
            personGameStats: self,
            teamScore: teamScore,
            opponentScore: opponentScore
        )

        if shifts == nil { shifts = [] }
        shifts?.append(shift)

        return shift
    }

    func endCurrentShift(teamScore: Int? = nil, opponentScore: Int? = nil) {
        currentShift?.endShift(teamScore: teamScore, opponentScore: opponentScore)
    }

    // MARK: - Aggregated Stat Helpers

    func aggregatedMade(forName name: String) -> Int {
        canonicalStats.filter { $0.statName == name }.reduce(0) { $0 + $1.made }
    }

    func aggregatedMissed(forName name: String) -> Int {
        canonicalStats.filter { $0.statName == name }.reduce(0) { $0 + $1.missed }
    }

    func aggregatedCount(forName name: String) -> Int {
        canonicalStats.filter { $0.statName == name }.reduce(0) { $0 + $1.count }
    }
}
