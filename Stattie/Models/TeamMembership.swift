import Foundation
import SwiftData

@Model
final class TeamMembership {
    var id: UUID = UUID()
    var joinedAt: Date = Date()
    var role: String = ""  // e.g., "player", "coach", "captain"
    var jerseyNumber: Int?
    var position: String = ""
    var isActive: Bool = true

    var person: Person?
    var team: Team?

    init(
        person: Person? = nil,
        team: Team? = nil,
        role: String = "player",
        jerseyNumber: Int? = nil,
        position: String = "",
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
    }
}
