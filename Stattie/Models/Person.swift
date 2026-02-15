import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var jerseyNumber: Int = 0
    var position: String = ""
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

    init(
        firstName: String = "",
        lastName: String = "",
        jerseyNumber: Int = 0,
        position: String = "",
        photoData: Data? = nil,
        isActive: Bool = true,
        owner: User? = nil
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.jerseyNumber = jerseyNumber
        self.position = position
        self.photoData = photoData
        self.isActive = isActive
        self.owner = owner
        self.createdAt = Date()
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
