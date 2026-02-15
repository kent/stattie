import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID = UUID()
    var gameDate: Date = Date()
    var opponent: String = ""
    var location: String = ""
    var notes: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()

    var sport: Sport?
    var trackedBy: User?
    var team: Team?

    var lockedByUserID: String?
    var lockExpiresAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PersonGameStats.game)
    var personStats: [PersonGameStats]? = []

    // Direct stats storage (for quick tracking without players)
    @Relationship(deleteRule: .cascade, inverse: \Stat.game)
    var stats: [Stat]? = []

    var isLocked: Bool {
        guard let expiresAt = lockExpiresAt else { return false }
        return expiresAt > Date()
    }

    var totalPoints: Int {
        // Points from person stats
        let personPoints = (personStats ?? []).reduce(0) { $0 + $1.totalPoints }
        // Points from direct game stats
        let directPoints = (stats ?? []).reduce(0) { $0 + $1.points }
        return personPoints + directPoints
    }

    // Helper to get or create a stat by name
    func stat(named name: String) -> Stat? {
        (stats ?? []).first { $0.statName == name }
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
}
