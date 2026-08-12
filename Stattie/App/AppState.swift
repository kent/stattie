import Foundation
import SwiftUI
import Observation

@Observable
final class AppState {
    enum MainTab: Int {
        case players = 0
        case teams = 1
        case activity = 2
        case academy = 3
        case settings = 4
    }

    static let shared = AppState()

    private let selectedTabKey = "selectedMainTab"
    private let pendingAcademyPlayerIDKey = "pendingAcademyPlayerID"

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
            AchievementManager.shared.synchronizeFromCloud(force: true)
        }
    }

    var selectedTabRaw: Int {
        get { UserDefaults.standard.integer(forKey: selectedTabKey) }
        set { UserDefaults.standard.set(newValue, forKey: selectedTabKey) }
    }

    var selectedTab: MainTab {
        get { MainTab(rawValue: selectedTabRaw) ?? .players }
        set { selectedTabRaw = newValue.rawValue }
    }

    var pendingAcademyPlayerID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: pendingAcademyPlayerIDKey) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: pendingAcademyPlayerIDKey)
        }
    }

    private init() {}

    func synchronizeFromCloud() {
        CloudSyncedPreferences.synchronizeFromCloudIfAvailable()
        AchievementManager.shared.synchronizeFromCloud(force: true)
    }

    func completeOnboarding(userID: UUID) {
        currentUserID = userID
        hasCompletedOnboarding = true
    }

    func navigateToAcademy(playerID: UUID?) {
        selectedTab = .academy
        pendingAcademyPlayerID = playerID
    }

    func reset() {
        hasCompletedOnboarding = false
        currentUserID = nil
        selectedTab = .players
        pendingAcademyPlayerID = nil
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
