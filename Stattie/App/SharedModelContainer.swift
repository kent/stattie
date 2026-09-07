import Foundation
import SwiftData

enum SharedModelContainer {
    static var schema: Schema {
        Schema([
            User.self,
            Person.self,
            Team.self,
            TeamMembership.self,
            Sport.self,
            StatDefinition.self,
            Game.self,
            PersonGameStats.self,
            Stat.self,
            Shift.self,
            ShiftStat.self,
            SyncedAppSettings.self,
            SyncedAchievementState.self
        ])
    }

    static var container: ModelContainer?
    static var isCloudKitBacked = false

    static func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }
}
