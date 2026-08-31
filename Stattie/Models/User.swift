import Foundation
import SwiftData

@Model
final class User {
    var id: UUID = UUID()
    var displayName: String = ""
    var cloudKitUserID: String?
    var createdAt: Date = Date()

    // Legacy streak fields are unused in the UI. They stay on the model so
    // existing SwiftData/CloudKit stores do not need a schema migration.
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
}
