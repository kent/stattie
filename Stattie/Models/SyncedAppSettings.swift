import Foundation
import SwiftData

// Legacy schema retained for existing iCloud stores. User records now drive
// onboarding directly; device navigation preferences no longer sync.
@Model
final class SyncedAppSettings {
    var id: UUID = UUID()
    var hasCompletedOnboarding: Bool = false
    var currentUserID: UUID?
    // Retained only for backward-compatible store migration; unused.
    var aiCoachEndpointURL: String = ""
    var aiCoachProxyToken: String = ""
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.updatedAt = Date()
    }
}
