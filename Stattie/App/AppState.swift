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

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var currentUserID: UUID? {
        didSet { UserDefaults.standard.set(currentUserID?.uuidString, forKey: "currentUserID") }
    }

    var selectedTabRaw: Int {
        didSet { UserDefaults.standard.set(selectedTabRaw, forKey: "selectedMainTab") }
    }

    var selectedTab: MainTab {
        get { MainTab(rawValue: selectedTabRaw) ?? .players }
        set { selectedTabRaw = newValue.rawValue }
    }

    private init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        currentUserID = defaults.string(forKey: "currentUserID").flatMap(UUID.init(uuidString:))
        selectedTabRaw = MainTab(rawValue: defaults.integer(forKey: "selectedMainTab"))?.rawValue
            ?? MainTab.players.rawValue
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

        return users.min {
            if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.createdAt < $1.createdAt
        }
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
