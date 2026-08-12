import Foundation
import SwiftData

@Model
final class Shift {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var shiftNumber: Int = 1
    var createdAt: Date = Date()

    // Plus/Minus tracking
    var startingTeamScore: Int = 0
    var startingOpponentScore: Int = 0
    var endingTeamScore: Int?
    var endingOpponentScore: Int?

    var personGameStats: PersonGameStats?

    // Legacy storage retained only so existing stores can be migrated. New writes use
    // `statRecords`, making Stat the single canonical attribution model.
    @Relationship(deleteRule: .cascade, inverse: \ShiftStat.shift)
    var stats: [ShiftStat]? = []

    @Relationship(deleteRule: .cascade, inverse: \Stat.shift)
    var statRecords: [Stat]? = []

    var isActive: Bool {
        endTime == nil
    }

    /// Plus/minus for this shift (team points - opponent points while on court)
    var plusMinus: Int? {
        guard let endTeam = endingTeamScore,
              let endOpp = endingOpponentScore else {
            return nil
        }
        let teamDiff = endTeam - startingTeamScore
        let oppDiff = endOpp - startingOpponentScore
        return teamDiff - oppDiff
    }

    /// Formatted plus/minus string (e.g., "+5", "-3", "0")
    var formattedPlusMinus: String {
        guard let pm = plusMinus else { return "--" }
        if pm > 0 {
            return "+\(pm)"
        }
        return "\(pm)"
    }

    /// Color for plus/minus display
    var plusMinusColor: String {
        guard let pm = plusMinus else { return "secondary" }
        if pm > 0 { return "green" }
        if pm < 0 { return "red" }
        return "secondary"
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Stat Aggregation

    var totalPoints: Int {
        canonicalStats.reduce(0) { $0 + $1.points }
    }

    var canonicalStats: [Stat] {
        var seen = Set<UUID>()
        return (statRecords ?? []).filter {
            $0.shift?.id == id &&
            $0.personGameStats?.id == personGameStats?.id &&
            $0.game?.id == personGameStats?.game?.id &&
            seen.insert($0.id).inserted
        }
    }

    func statValue(forName name: String) -> Stat? {
        canonicalStats.first { $0.statName == name }
    }

    func statRecords(forName name: String) -> [Stat] {
        canonicalStats.filter { $0.statName == name }
    }

    func legacyStatValue(forName name: String) -> ShiftStat? {
        (stats ?? []).first { $0.statName == name }
    }

    func totalMade(forName name: String) -> Int {
        statRecords(forName: name).reduce(0) { $0 + $1.made }
    }

    func totalMissed(forName name: String) -> Int {
        statRecords(forName: name).reduce(0) { $0 + $1.missed }
    }

    func totalCount(forName name: String) -> Int {
        statRecords(forName: name).reduce(0) { $0 + $1.count }
    }

    init(
        shiftNumber: Int = 1,
        personGameStats: PersonGameStats? = nil,
        teamScore: Int = 0,
        opponentScore: Int = 0
    ) {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.shiftNumber = shiftNumber
        self.personGameStats = personGameStats
        self.createdAt = Date()
        self.startingTeamScore = teamScore
        self.startingOpponentScore = opponentScore
    }

    func endShift(
        teamScore: Int? = nil,
        opponentScore: Int? = nil,
        at date: Date = Date()
    ) {
        if endTime == nil {
            endTime = date
            endingTeamScore = teamScore ?? startingTeamScore
            endingOpponentScore = opponentScore ?? startingOpponentScore
        }
    }
}
