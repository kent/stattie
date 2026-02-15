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

    @Relationship(deleteRule: .cascade, inverse: \ShiftStat.shift)
    var stats: [ShiftStat]? = []

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
        (stats ?? []).reduce(0) { $0 + $1.points }
    }

    func statValue(forName name: String) -> ShiftStat? {
        (stats ?? []).first { $0.statName == name }
    }

    func totalMade(forName name: String) -> Int {
        statValue(forName: name)?.made ?? 0
    }

    func totalMissed(forName name: String) -> Int {
        statValue(forName: name)?.missed ?? 0
    }

    func totalCount(forName name: String) -> Int {
        statValue(forName: name)?.count ?? 0
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

    func endShift(teamScore: Int? = nil, opponentScore: Int? = nil) {
        if endTime == nil {
            endTime = Date()
            if let team = teamScore {
                endingTeamScore = team
            }
            if let opp = opponentScore {
                endingOpponentScore = opp
            }
        }
    }
}
