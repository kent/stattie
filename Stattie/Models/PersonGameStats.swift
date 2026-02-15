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
        (shifts ?? []).first { $0.isActive }
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

    // MARK: - Aggregated Stats from Shifts

    var totalPointsFromShifts: Int {
        (shifts ?? []).reduce(0) { $0 + $1.totalPoints }
    }

    var totalPoints: Int {
        // Combine direct stats and shift stats
        let directPoints = (stats ?? []).reduce(0) { $0 + $1.points }
        return directPoints + totalPointsFromShifts
    }

    var totalRebounds: Int {
        let drebs = (stats ?? []).first(where: { $0.statName == "DREB" })?.count ?? 0
        let orebs = (stats ?? []).first(where: { $0.statName == "OREB" })?.count ?? 0
        return drebs + orebs
    }

    var totalSteals: Int {
        (stats ?? []).first(where: { $0.statName == "STL" })?.count ?? 0
    }

    var totalAssists: Int {
        (stats ?? []).first(where: { $0.statName == "AST" })?.count ?? 0
    }

    var totalFouls: Int {
        (stats ?? []).first(where: { $0.statName == "PF" })?.count ?? 0
    }

    init(person: Person? = nil, game: Game? = nil) {
        self.id = UUID()
        self.person = person
        self.game = game
        self.createdAt = Date()
    }

    func stat(forName name: String) -> Stat? {
        (stats ?? []).first { $0.statName == name }
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
        // End any active shift first (without scores - they should be passed separately)
        currentShift?.endShift()

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
        let directMade = stat(forName: name)?.made ?? 0
        let shiftMade = (shifts ?? []).reduce(0) { $0 + ($1.statValue(forName: name)?.made ?? 0) }
        return directMade + shiftMade
    }

    func aggregatedMissed(forName name: String) -> Int {
        let directMissed = stat(forName: name)?.missed ?? 0
        let shiftMissed = (shifts ?? []).reduce(0) { $0 + ($1.statValue(forName: name)?.missed ?? 0) }
        return directMissed + shiftMissed
    }

    func aggregatedCount(forName name: String) -> Int {
        let directCount = stat(forName: name)?.count ?? 0
        let shiftCount = (shifts ?? []).reduce(0) { $0 + ($1.statValue(forName: name)?.count ?? 0) }
        return directCount + shiftCount
    }
}
