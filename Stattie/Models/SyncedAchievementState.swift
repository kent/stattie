import Foundation
import SwiftData

// Immutable progress snapshots are merged by union, including legacy rows.
// This avoids last-writer-wins losses when devices earn achievements offline.
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
