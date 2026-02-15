import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var jerseyNumber: Int = 0
    var position: String = ""
    var positionAssignmentsJSON: String?  // JSON-encoded PositionAssignments for structured positions
    var photoData: Data?
    var isActive: Bool = true
    var createdAt: Date = Date()

    var owner: User?

    @Relationship(deleteRule: .cascade, inverse: \TeamMembership.person)
    var teamMemberships: [TeamMembership]? = []

    @Relationship(deleteRule: .cascade, inverse: \PersonGameStats.person)
    var gameStats: [PersonGameStats]? = []

    var teams: [Team] {
        (teamMemberships ?? []).compactMap { $0.team }
    }

    var fullName: String {
        if firstName.isEmpty && lastName.isEmpty {
            return "Person #\(jerseyNumber)"
        }
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var displayName: String {
        if jerseyNumber > 0 {
            return "#\(jerseyNumber) \(fullName)"
        }
        return fullName
    }

    /// Get structured position assignments (for soccer)
    var positionAssignments: PositionAssignments {
        get {
            PositionAssignments.fromJSON(positionAssignmentsJSON)
        }
        set {
            positionAssignmentsJSON = newValue.toJSON()
            // Also update the legacy position string for display
            position = newValue.displayText
        }
    }

    /// Display text for position (uses structured if available, falls back to legacy string)
    var positionDisplayText: String {
        let assignments = positionAssignments
        if !assignments.isEmpty {
            return assignments.displayText
        }
        return position
    }

    /// Short position text for compact displays
    var positionShortText: String {
        let assignments = positionAssignments
        if !assignments.isEmpty {
            return assignments.shortDisplayText
        }
        return position
    }

    /// Check if person plays as goalkeeper (any percentage)
    var isGoalkeeper: Bool {
        positionAssignments.includesGoalkeeper
    }

    /// Check if person has split positions
    var hasSplitPositions: Bool {
        positionAssignments.assignments.count > 1
    }

    init(
        firstName: String = "",
        lastName: String = "",
        jerseyNumber: Int = 0,
        position: String = "",
        positionAssignments: PositionAssignments? = nil,
        photoData: Data? = nil,
        isActive: Bool = true,
        owner: User? = nil
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.positionAssignmentsJSON = positionAssignments?.toJSON()
        self.photoData = photoData
        self.isActive = isActive
        self.owner = owner
        self.createdAt = Date()

        // If structured assignments provided, update legacy position string
        if let assignments = positionAssignments, !assignments.isEmpty {
            self.position = assignments.displayText
        }
    }
}

// MARK: - Stats Helpers

extension Person {
    /// Total number of completed games
    var completedGamesCount: Int {
        (gameStats ?? []).filter { $0.game?.isCompleted == true }.count
    }

    /// Check if player has any active (incomplete) games
    var hasActiveGame: Bool {
        (gameStats ?? []).contains { $0.game?.isCompleted == false }
    }

    /// Total points across all completed games
    var totalCareerPoints: Int {
        (gameStats ?? [])
            .filter { $0.game?.isCompleted == true }
            .compactMap { $0.game?.totalPoints }
            .reduce(0, +)
    }

    /// Average points per game
    var averagePointsPerGame: Double {
        guard completedGamesCount > 0 else { return 0 }
        return Double(totalCareerPoints) / Double(completedGamesCount)
    }

    /// Most recent game date
    var lastGameDate: Date? {
        (gameStats ?? [])
            .compactMap { $0.game?.gameDate }
            .max()
    }

    /// Career high points in a single game
    var careerHighPoints: Int {
        (gameStats ?? [])
            .filter { $0.game?.isCompleted == true }
            .compactMap { $0.game?.totalPoints }
            .max() ?? 0
    }

    /// Career high rebounds in a single game
    var careerHighRebounds: Int {
        (gameStats ?? [])
            .filter { $0.game?.isCompleted == true }
            .map { ($0.game?.stat(named: "DREB")?.count ?? 0) + ($0.game?.stat(named: "OREB")?.count ?? 0) }
            .max() ?? 0
    }

    /// Career high assists in a single game
    var careerHighAssists: Int {
        (gameStats ?? [])
            .filter { $0.game?.isCompleted == true }
            .compactMap { $0.game?.stat(named: "AST")?.count }
            .max() ?? 0
    }

    /// Total career plus/minus across all games with shift tracking
    var careerPlusMinus: Int {
        (gameStats ?? [])
            .filter { $0.game?.isCompleted == true }
            .map { $0.totalPlusMinus }
            .reduce(0, +)
    }

    /// Formatted career plus/minus
    var formattedCareerPlusMinus: String {
        let pm = careerPlusMinus
        if pm > 0 { return "+\(pm)" }
        return "\(pm)"
    }

    /// Average plus/minus per game (only games with shift tracking)
    var averagePlusMinus: Double {
        let gamesWithShifts = (gameStats ?? [])
            .filter { $0.game?.isCompleted == true && !$0.completedShifts.isEmpty }

        guard !gamesWithShifts.isEmpty else { return 0 }

        let totalPM = gamesWithShifts.map { $0.totalPlusMinus }.reduce(0, +)
        return Double(totalPM) / Double(gamesWithShifts.count)
    }
}

// MARK: - Sharing Support

extension Person {
    /// Checks if this person is shared (async operation via CloudKitShareManager)
    func checkIsShared() async -> Bool {
        await CloudKitShareManager.shared.isPersonShared(self)
    }

    /// Checks if current user is the owner of this person's share
    func checkIsOwner() async -> Bool {
        await CloudKitShareManager.shared.isOwner(of: self)
    }

    /// Gets the count of participants this person is shared with (excluding owner)
    func getShareParticipantCount() async -> Int {
        await CloudKitShareManager.shared.getParticipantCount(for: self)
    }
}
