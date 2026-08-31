import Foundation
import SwiftUI
import SwiftData

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

class AchievementManager {
    static let shared = AchievementManager()

    private let unlockedKey = "unlockedAchievements"
    private let totalPointsKey = "achievementPoints"
    private let localUpdatedAtPrefix = "achievementLocalUpdatedAt"

    var unlockedAchievements: Set<AchievementType> {
        get {
            synchronizeFromCloud()
            guard let data = UserDefaults.standard.data(forKey: unlockedKey),
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return []
            }
            return Set(decoded.compactMap { AchievementType(rawValue: $0) })
        }
        set {
            let strings = Set(newValue.map { $0.rawValue })
            if let data = try? JSONEncoder().encode(strings) {
                UserDefaults.standard.set(data, forKey: unlockedKey)
            }
            markLocalMutationAndPush()
        }
    }

    var totalPoints: Int {
        get {
            synchronizeFromCloud()
            return UserDefaults.standard.integer(forKey: totalPointsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: totalPointsKey)
            markLocalMutationAndPush()
        }
    }

    func unlock(_ achievement: AchievementType) -> Bool {
        guard !unlockedAchievements.contains(achievement) else { return false }

        var unlocked = unlockedAchievements
        unlocked.insert(achievement)
        unlockedAchievements = unlocked
        totalPoints += achievement.points

        return true
    }

    func synchronizeFromCloud(force: Bool = false) {
        guard let context = SharedModelContainer.makeContext() else { return }

        let ownerUserID = AppState.shared.currentUserID
        let state = fetchOrCreateState(ownerUserID: ownerUserID, context: context)

        let localUpdatedAt = UserDefaults.standard.double(forKey: localUpdatedAtKey(for: ownerUserID))
        let remoteUpdatedAt = state.updatedAt.timeIntervalSince1970

        if remoteUpdatedAt > localUpdatedAt {
            applyRemoteStateToDefaults(state)
            UserDefaults.standard.set(remoteUpdatedAt, forKey: localUpdatedAtKey(for: ownerUserID))
            return
        }

        if force || localUpdatedAt > remoteUpdatedAt {
            pushLocalStateToCloud(ownerUserID: ownerUserID, context: context)
        }
    }

    func isUnlocked(_ achievement: AchievementType) -> Bool {
        unlockedAchievements.contains(achievement)
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

    // MARK: - Cloud Sync

    private func markLocalMutationAndPush() {
        let ownerUserID = AppState.shared.currentUserID
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: localUpdatedAtKey(for: ownerUserID))

        guard let context = SharedModelContainer.makeContext() else { return }
        pushLocalStateToCloud(ownerUserID: ownerUserID, context: context)
    }

    private func localUpdatedAtKey(for ownerUserID: UUID?) -> String {
        "\(localUpdatedAtPrefix).\(ownerUserID?.uuidString ?? "global")"
    }

    private func fetchOrCreateState(ownerUserID: UUID?, context: ModelContext) -> SyncedAchievementState {
        let descriptor = FetchDescriptor<SyncedAchievementState>()
        if let states = try? context.fetch(descriptor),
           let existing = states.first(where: { $0.ownerUserID == ownerUserID }) {
            return existing
        }

        let created = SyncedAchievementState(ownerUserID: ownerUserID)
        context.insert(created)
        _ = writeLocalStateIfNeeded(to: created, ownerUserID: ownerUserID)
        save(context: context)
        return created
    }

    private func pushLocalStateToCloud(ownerUserID: UUID?, context: ModelContext) {
        let state = fetchOrCreateState(ownerUserID: ownerUserID, context: context)
        guard writeLocalStateIfNeeded(to: state, ownerUserID: ownerUserID) else { return }
        save(context: context)
    }

    @discardableResult
    private func writeLocalStateIfNeeded(
        to state: SyncedAchievementState,
        ownerUserID: UUID?
    ) -> Bool {
        var changed = false

        let unlockedData = UserDefaults.standard.data(forKey: unlockedKey)
        let unlockedIDs = (try? JSONDecoder().decode(Set<String>.self, from: unlockedData ?? Data())) ?? []
        let encoded = (try? String(data: JSONEncoder().encode(Array(unlockedIDs).sorted()), encoding: .utf8)) ?? "[]"
        if state.unlockedAchievementIDsJSON != encoded {
            state.unlockedAchievementIDsJSON = encoded
            changed = true
        }

        let points = UserDefaults.standard.integer(forKey: totalPointsKey)
        if state.totalPoints != points {
            state.totalPoints = points
            changed = true
        }

        if state.ownerUserID != ownerUserID {
            state.ownerUserID = ownerUserID
            changed = true
        }

        let localUpdatedAt = UserDefaults.standard.double(forKey: localUpdatedAtKey(for: ownerUserID))
        if localUpdatedAt > 0 {
            let localDate = Date(timeIntervalSince1970: localUpdatedAt)
            if state.updatedAt != localDate {
                state.updatedAt = localDate
                changed = true
            }
        } else if changed {
            state.updatedAt = Date()
        }

        return changed
    }

    private func applyRemoteStateToDefaults(_ state: SyncedAchievementState) {
        let unlockedIDs = ((try? JSONDecoder().decode([String].self, from: Data(state.unlockedAchievementIDsJSON.utf8))) ?? [])
        let unique = Set(unlockedIDs)

        if let data = try? JSONEncoder().encode(unique) {
            UserDefaults.standard.set(data, forKey: unlockedKey)
        }
        UserDefaults.standard.set(state.totalPoints, forKey: totalPointsKey)
    }

    private func save(context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Keep local progress if cloud write fails.
        }
    }
}
