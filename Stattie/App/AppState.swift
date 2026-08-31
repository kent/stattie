import Foundation
import SwiftUI
import Observation

@Observable
final class AppState {
    enum MainTab: Int {
        case players = 0
        case activity = 2
        case settings = 4
    }

    static let shared = AppState()

    private let selectedTabKey = "selectedMainTab"

    var hasCompletedOnboarding: Bool {
        get {
            CloudSyncedPreferences.bootstrapIfNeeded()
            return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
            CloudSyncedPreferences.notifyLocalMutation()
        }
    }

    var currentUserID: UUID? {
        get {
            CloudSyncedPreferences.bootstrapIfNeeded()
            guard let string = UserDefaults.standard.string(forKey: "currentUserID") else { return nil }
            return UUID(uuidString: string)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: "currentUserID")
            CloudSyncedPreferences.notifyLocalMutation()
            AchievementManager.shared.synchronizeFromCloud()
        }
    }

    var selectedTabRaw: Int {
        get {
            let storedValue = UserDefaults.standard.integer(forKey: selectedTabKey)
            return MainTab(rawValue: storedValue)?.rawValue ?? MainTab.players.rawValue
        }
        set { UserDefaults.standard.set(newValue, forKey: selectedTabKey) }
    }

    var selectedTab: MainTab {
        get { MainTab(rawValue: selectedTabRaw) ?? .players }
        set { selectedTabRaw = newValue.rawValue }
    }

    private init() {}

    func synchronizeFromCloud() {
        CloudSyncedPreferences.synchronizeFromCloudIfAvailable()
        AchievementManager.shared.synchronizeFromCloud()
    }

    func completeOnboarding(userID: UUID) {
        currentUserID = userID
        hasCompletedOnboarding = true
    }

    func reset() {
        hasCompletedOnboarding = false
        currentUserID = nil
        selectedTab = .players
    }
}

// MARK: - Current User Resolution

extension Collection where Element == User {
    var resolvedCurrentUser: User? {
        let users = Array(self)
        guard !users.isEmpty else { return nil }

        if let currentUserID = AppState.shared.currentUserID,
           let matched = users.first(where: { $0.id == currentUserID }) {
            return matched
        }

        let fallback = users.sorted { $0.createdAt < $1.createdAt }.first
        if let fallback, AppState.shared.currentUserID == nil {
            // Backward-compatible migration path for installs created
            // before currentUserID was persisted.
            AppState.shared.currentUserID = fallback.id
        }
        return fallback
    }
}

// MARK: - Ownership Checks

extension Person {
    func isOwned(by user: User?) -> Bool {
        guard let user else { return false }
        return owner?.id == user.id
    }
}

extension Team {
    func isOwned(by user: User?) -> Bool {
        guard let user else { return false }
        return owner?.id == user.id
    }
}

extension Game {
    func isOwned(by user: User?) -> Bool {
        guard let user else { return false }

        if trackedBy?.id == user.id {
            return true
        }

        if team?.owner?.id == user.id {
            return true
        }

        return (personStats ?? []).contains { $0.person?.owner?.id == user.id }
    }
}
