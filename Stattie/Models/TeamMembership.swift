import Foundation
import SwiftData

@Model
final class TeamMembership {
    var id: UUID = UUID()
    var joinedAt: Date = Date()
    var role: String = ""  // e.g., "player", "coach", "captain"
    var jerseyNumber: Int?
    var position: String = ""  // Legacy - kept for backwards compatibility
    var positionAssignmentsJSON: String?  // JSON-encoded position assignments for this team
    var isActive: Bool = true

    var person: Person?
    var team: Team?

    // MARK: - Position Assignments for this Team

    /// Structured position assignments with percentages (e.g., 60% Point Guard, 40% Shooting Guard)
    var positionAssignments: PositionAssignments {
        get {
            guard let json = positionAssignmentsJSON else {
                // Fall back to legacy position string if available
                if !position.isEmpty {
                    return PositionAssignments(assignments: [])
                }
                return PositionAssignments()
            }
            return PositionAssignments.fromJSON(json) ?? PositionAssignments()
        }
        set {
            positionAssignmentsJSON = newValue.toJSON()
            // Update legacy field for backwards compatibility
            position = newValue.displayText
        }
    }

    /// Whether this membership has multiple positions assigned
    var hasMultiplePositions: Bool {
        positionAssignments.assignments.count > 1
    }

    /// The primary (default) position for this team membership
    var primaryPosition: SoccerPosition? {
        positionAssignments.primaryPosition
    }

    /// Display text for positions on this team
    var positionDisplayText: String {
        if positionAssignments.isEmpty {
            return position.isEmpty ? "No position" : position
        }
        return positionAssignments.displayText
    }

    /// Short display text for positions
    var positionShortText: String {
        if positionAssignments.isEmpty {
            return position.isEmpty ? "-" : position
        }
        return positionAssignments.shortDisplayText
    }

    init(
        person: Person? = nil,
        team: Team? = nil,
        role: String = "player",
        jerseyNumber: Int? = nil,
        position: String = "",
        positionAssignments: PositionAssignments? = nil,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.person = person
        self.team = team
        self.role = role
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.isActive = isActive
        self.joinedAt = Date()

        if let assignments = positionAssignments {
            self.positionAssignmentsJSON = assignments.toJSON()
        }
    }
}
