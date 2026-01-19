import Foundation
import SwiftData

@Model
final class Stat {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var made: Int = 0
    var missed: Int = 0
    var count: Int = 0

    // Store stat info directly so we don't need StatDefinition
    var statName: String = ""  // "2PT", "3PT", "FT", "DREB", "OREB", "STL", "PF"
    var pointValue: Int = 0    // Points per made shot (2, 3, 1, or 0)

    var definition: StatDefinition?
    var playerGameStats: PlayerGameStats?
    var game: Game?  // Direct link to game (when tracking without players)

    var total: Int {
        made + missed + count
    }

    var percentage: Double? {
        let attempts = made + missed
        guard attempts > 0 else { return nil }
        return Double(made) / Double(attempts)
    }

    var formattedPercentage: String? {
        guard let pct = percentage else { return nil }
        return String(format: "%.0f%%", pct * 100)
    }

    var points: Int {
        pointValue * made
    }

    var displayValue: String {
        if pointValue > 0 {
            return "\(made)/\(made + missed)"
        }
        return "\(count)"
    }

    init(
        statName: String = "",
        pointValue: Int = 0,
        made: Int = 0,
        missed: Int = 0,
        count: Int = 0,
        definition: StatDefinition? = nil,
        playerGameStats: PlayerGameStats? = nil
    ) {
        self.id = UUID()
        self.statName = statName
        self.pointValue = pointValue
        self.made = made
        self.missed = missed
        self.count = count
        self.definition = definition
        self.playerGameStats = playerGameStats
        self.timestamp = Date()
    }
}
