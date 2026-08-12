import Foundation
import SwiftData

@Model
final class SyncedAppSettings {
    var id: UUID = UUID()
    var hasCompletedOnboarding: Bool = false
    var currentUserID: UUID?
    // Retained only for backward-compatible store migration; always cleared.
    var aiCoachEndpointURL: String = ""
    var aiCoachProxyToken: String = ""
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.updatedAt = Date()
    }
}
