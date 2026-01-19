import Foundation
import SwiftUI
import Observation

@Observable
final class AppState {
    static let shared = AppState()

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var currentUserID: UUID? {
        get {
            guard let string = UserDefaults.standard.string(forKey: "currentUserID") else { return nil }
            return UUID(uuidString: string)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: "currentUserID")
        }
    }

    private init() {}

    func completeOnboarding(userID: UUID) {
        currentUserID = userID
        hasCompletedOnboarding = true
    }

    func reset() {
        hasCompletedOnboarding = false
        currentUserID = nil
    }
}
