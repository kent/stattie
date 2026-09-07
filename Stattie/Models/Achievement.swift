import Observation
import OSLog
import Foundation
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.stattie.app", category: "Achievements")

// MARK: - Achievement Definitions

enum AchievementType: String, CaseIterable, Codable {
    // Game milestones
    case firstGame = "first_game"
    case tenGames = "ten_games"
    case fiftyGames = "fifty_games"
    case hundredGames = "hundred_games"

    // Streak achievements
    case threeDayStreak = "three_day_streak"
    case sevenDayStreak = "seven_day_streak"
    case thirtyDayStreak = "thirty_day_streak"

    // Performance achievements
    case doubleDouble = "double_double"
    case tripleDouble = "triple_double"
    case twentyPoints = "twenty_points"
    case thirtyPoints = "thirty_points"
    case fiftyPoints = "fifty_points"

    // Soccer achievements
    case hatTrick = "hat_trick"
    case cleanSheet = "clean_sheet"

    // Social achievements
    case firstShare = "first_share"
    case sharedPlayer = "shared_player"

    var title: String {
        switch self {
        case .firstGame: return "First Steps"
        case .tenGames: return "Getting Serious"
        case .fiftyGames: return "Dedicated Tracker"
        case .hundredGames: return "Stat Master"
        case .threeDayStreak: return "On a Roll"
        case .sevenDayStreak: return "Week Warrior"
        case .thirtyDayStreak: return "Monthly Champion"
        case .doubleDouble: return "Double Trouble"
        case .tripleDouble: return "Triple Threat"
        case .twentyPoints: return "Score Machine"
        case .thirtyPoints: return "Hot Hand"
        case .fiftyPoints: return "Unstoppable"
        case .hatTrick: return "Hat Trick Hero"
        case .cleanSheet: return "Brick Wall"
        case .firstShare: return "Family Update"
        case .sharedPlayer: return "Stattie Supporter"
        }
    }

    var description: String {
        switch self {
        case .firstGame: return "Track your first game"
        case .tenGames: return "Track 10 games"
        case .fiftyGames: return "Track 50 games"
        case .hundredGames: return "Track 100 games"
        case .threeDayStreak: return "3-day tracking streak"
        case .sevenDayStreak: return "7-day tracking streak"
        case .thirtyDayStreak: return "30-day tracking streak"
        case .doubleDouble: return "Record a double-double"
        case .tripleDouble: return "Record a triple-double"
        case .twentyPoints: return "Score 20+ points in a game"
        case .thirtyPoints: return "Score 30+ points in a game"
        case .fiftyPoints: return "Score 50+ points in a game"
        case .hatTrick: return "Score 3 goals in a game"
        case .cleanSheet: return "Record a clean sheet (goalkeeper)"
        case .firstShare: return "Share your first game stats"
        case .sharedPlayer: return "Legacy achievement"
        }
    }

    var icon: String {
        switch self {
        case .firstGame: return "flag.fill"
        case .tenGames: return "10.circle.fill"
        case .fiftyGames: return "star.circle.fill"
        case .hundredGames: return "crown.fill"
        case .threeDayStreak: return "flame"
        case .sevenDayStreak: return "flame.fill"
        case .thirtyDayStreak: return "flame.circle.fill"
        case .doubleDouble: return "2.circle.fill"
        case .tripleDouble: return "3.circle.fill"
        case .twentyPoints: return "20.circle"
        case .thirtyPoints: return "30.circle"
        case .fiftyPoints: return "50.circle"
        case .hatTrick: return "soccerball"
        case .cleanSheet: return "hand.raised.fill"
        case .firstShare: return "square.and.arrow.up"
        case .sharedPlayer: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstGame: return .green
        case .tenGames: return .blue
        case .fiftyGames: return .purple
        case .hundredGames: return .yellow
        case .threeDayStreak: return .orange
        case .sevenDayStreak: return .orange
        case .thirtyDayStreak: return .red
        case .doubleDouble: return .indigo
        case .tripleDouble: return .purple
        case .twentyPoints: return .blue
        case .thirtyPoints: return .cyan
        case .fiftyPoints: return .mint
        case .hatTrick: return .green
        case .cleanSheet: return .blue
        case .firstShare: return .teal
        case .sharedPlayer: return .green
        }
    }

    var points: Int {
        switch self {
        case .firstGame: return 10
        case .tenGames: return 50
        case .fiftyGames: return 200
        case .hundredGames: return 500
        case .threeDayStreak: return 30
        case .sevenDayStreak: return 100
        case .thirtyDayStreak: return 500
        case .doubleDouble: return 50
        case .tripleDouble: return 100
        case .twentyPoints: return 25
        case .thirtyPoints: return 50
        case .fiftyPoints: return 100
        case .hatTrick: return 75
        case .cleanSheet: return 50
        case .firstShare: return 25
        case .sharedPlayer: return 50
        }
    }

    /// Streak and legacy types stay in storage so already-unlocked IDs still decode,
    /// but they are hidden from the achievements catalog.
    var isVisibleInCatalog: Bool {
        switch self {
        case .sharedPlayer, .threeDayStreak, .sevenDayStreak, .thirtyDayStreak:
            return false
        default:
            return true
        }
    }

    static var visibleCases: [AchievementType] {
        allCases.filter(\.isVisibleInCatalog)
    }
}

// MARK: - Achievement Manager

@MainActor
@Observable
final class AchievementManager {
    static let shared = AchievementManager()

    private let defaults: UserDefaults
    private var unlockedIDs: Set<String> = []
    private(set) var totalPoints = 0

    var unlockedAchievements: Set<AchievementType> {
        Set(unlockedIDs.compactMap(AchievementType.init(rawValue:)))
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isUnlocked(_ achievement: AchievementType) -> Bool {
        unlockedIDs.contains(achievement.rawValue)
    }

    func unlock(_ achievement: AchievementType) -> Bool {
        synchronizeFromCloud()
        guard let ownerID = AppState.shared.currentUserID,
              unlockedIDs.insert(achievement.rawValue).inserted else { return false }
        totalPoints += achievement.points
        cacheLocally(ownerID: ownerID)
        synchronizeFromCloud()
        return true
    }

    /// Merge earned achievements monotonically. Separate devices may create
    /// snapshots concurrently; their union preserves both without clock ordering.
    /// Reading UI properties never creates or saves SwiftData records.
    func synchronizeFromCloud() {
        guard let ownerID = AppState.shared.currentUserID else {
            unlockedIDs = []
            totalPoints = 0
            return
        }
        let prefix = cachePrefix(ownerID)
        var localIDs = decode(defaults.data(forKey: prefix + ".ids"))
        var localPoints = defaults.integer(forKey: prefix + ".points")

        // Adopt pre-account caches once, keeping them available if a save fails.
        let legacyOwnerKey = "achievementLegacyOwnerID"
        if defaults.string(forKey: legacyOwnerKey) == nil {
            defaults.set(ownerID.uuidString, forKey: legacyOwnerKey)
        }
        let ownsLegacy = defaults.string(forKey: legacyOwnerKey) == ownerID.uuidString
        if ownsLegacy {
            localIDs.formUnion(decode(defaults.data(forKey: "unlockedAchievements")))
            localPoints = max(localPoints, defaults.integer(forKey: "achievementPoints"))
        }
        unlockedIDs = localIDs
        totalPoints = max(localPoints, points(for: localIDs))

        guard let context = SharedModelContainer.makeContext() else { return }
        do {
            let states = try context.fetch(FetchDescriptor<SyncedAchievementState>())
                .filter { $0.ownerUserID == ownerID || (ownsLegacy && $0.ownerUserID == nil) }
            let remoteIDs = states.reduce(into: Set<String>()) { result, state in
                result.formUnion(decode(Data(state.unlockedAchievementIDsJSON.utf8)))
            }
            let remotePoints = max(states.map(\.totalPoints).max() ?? 0, points(for: remoteIDs))
            unlockedIDs.formUnion(remoteIDs)
            totalPoints = max(totalPoints, remotePoints, points(for: unlockedIDs))
            cacheLocally(ownerID: ownerID)

            guard !unlockedIDs.isSubset(of: remoteIDs) || totalPoints > remotePoints else { return }
            // Append only when local progress is missing remotely. Never overwrite
            // a shared snapshot: concurrent offline unlocks must both survive.
            let snapshot = SyncedAchievementState(ownerUserID: ownerID)
            snapshot.unlockedAchievementIDsJSON = String(
                decoding: try JSONEncoder().encode(unlockedIDs.sorted()), as: UTF8.self
            )
            snapshot.totalPoints = totalPoints
            context.insert(snapshot)
            try context.save()
        } catch {
            logger.error("Could not persist achievements: \(error.localizedDescription)")
        }
    }

    private func cachePrefix(_ ownerID: UUID) -> String {
        "achievements.\(ownerID.uuidString)"
    }

    private func decode(_ data: Data?) -> Set<String> {
        guard let data else { return [] }
        return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }

    private func points(for ids: Set<String>) -> Int {
        ids.compactMap(AchievementType.init(rawValue:)).reduce(0) { $0 + $1.points }
    }

    private func cacheLocally(ownerID: UUID) {
        let prefix = cachePrefix(ownerID)
        defaults.set(try? JSONEncoder().encode(unlockedIDs), forKey: prefix + ".ids")
        defaults.set(totalPoints, forKey: prefix + ".points")
    }

    func checkGameAchievements(completedGamesCount: Int, points: Int, rebounds: Int, assists: Int, steals: Int, goals: Int) -> [AchievementType] {
        var newAchievements: [AchievementType] = []

        // Game count achievements
        if completedGamesCount >= 1 && unlock(.firstGame) { newAchievements.append(.firstGame) }
        if completedGamesCount >= 10 && unlock(.tenGames) { newAchievements.append(.tenGames) }
        if completedGamesCount >= 50 && unlock(.fiftyGames) { newAchievements.append(.fiftyGames) }
        if completedGamesCount >= 100 && unlock(.hundredGames) { newAchievements.append(.hundredGames) }

        // Points achievements
        if points >= 20 && unlock(.twentyPoints) { newAchievements.append(.twentyPoints) }
        if points >= 30 && unlock(.thirtyPoints) { newAchievements.append(.thirtyPoints) }
        if points >= 50 && unlock(.fiftyPoints) { newAchievements.append(.fiftyPoints) }

        // Double/triple double
        var doubleDigitCategories = 0
        if points >= 10 { doubleDigitCategories += 1 }
        if rebounds >= 10 { doubleDigitCategories += 1 }
        if assists >= 10 { doubleDigitCategories += 1 }
        if steals >= 10 { doubleDigitCategories += 1 }

        if doubleDigitCategories >= 2 && unlock(.doubleDouble) { newAchievements.append(.doubleDouble) }
        if doubleDigitCategories >= 3 && unlock(.tripleDouble) { newAchievements.append(.tripleDouble) }

        // Soccer
        if goals >= 3 && unlock(.hatTrick) { newAchievements.append(.hatTrick) }

        return newAchievements
    }

}
