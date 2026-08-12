import Foundation
import SwiftData

@Model
final class SyncedAchievementState {
    var id: UUID = UUID()
    var ownerUserID: UUID?
    var unlockedAchievementIDsJSON: String = "[]"
    var totalPoints: Int = 0
    var updatedAt: Date = Date()

    init(ownerUserID: UUID? = nil) {
        self.id = UUID()
        self.ownerUserID = ownerUserID
        self.updatedAt = Date()
    }
}
