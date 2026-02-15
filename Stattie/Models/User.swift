import Foundation
import SwiftData

@Model
final class User {
    var id: UUID = UUID()
    var displayName: String = ""
    var cloudKitUserID: String?
    var createdAt: Date = Date()

    // Streak tracking
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastGameDate: Date?

    @Relationship(deleteRule: .nullify, inverse: \Game.trackedBy)
    var trackedGames: [Game]? = []

    @Relationship(deleteRule: .cascade, inverse: \Person.owner)
    var people: [Person]? = []

    @Relationship(deleteRule: .cascade, inverse: \Team.owner)
    var teams: [Team]? = []

    init(displayName: String = "", cloudKitUserID: String? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.cloudKitUserID = cloudKitUserID
        self.createdAt = Date()
        self.currentStreak = 0
        self.longestStreak = 0
    }

    /// Update streak when a game is completed
    func recordGameCompletion(on date: Date = Date()) {
        let calendar = Calendar.current

        if let lastDate = lastGameDate {
            let daysBetween = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: date)).day ?? 0

            if daysBetween == 0 {
                // Same day, no change
                return
            } else if daysBetween == 1 {
                // Consecutive day - extend streak
                currentStreak += 1
            } else {
                // Gap - reset streak
                currentStreak = 1
            }
        } else {
            // First game ever
            currentStreak = 1
        }

        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastGameDate = date
    }

    /// Check if streak is at risk (no game today, had game yesterday)
    var streakAtRisk: Bool {
        guard let lastDate = lastGameDate, currentStreak > 0 else { return false }
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: Date())).day ?? 0
        return daysSince == 1
    }
}
