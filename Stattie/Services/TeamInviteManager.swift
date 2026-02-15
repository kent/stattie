import Foundation
import SwiftUI
import UIKit
import Contacts

/// Manages team invitations and tracks viral growth metrics
class TeamInviteManager: ObservableObject {
    static let shared = TeamInviteManager()

    private let defaults = UserDefaults.standard

    // Keys
    private let invitesSentKey = "teamInvitesSent"
    private let invitesAcceptedKey = "teamInvitesAccepted"
    private let pendingInvitesKey = "pendingTeamInvites"
    private let inviteHistoryKey = "teamInviteHistory"
    private let lastInviteBatchKey = "lastInviteBatchDate"

    @Published var invitesSent: Int {
        didSet { defaults.set(invitesSent, forKey: invitesSentKey) }
    }

    @Published var invitesAccepted: Int {
        didSet { defaults.set(invitesAccepted, forKey: invitesAcceptedKey) }
    }

    @Published var pendingInvites: [PendingInvite] {
        didSet { savePendingInvites() }
    }

    var lastInviteBatchDate: Date? {
        get { defaults.object(forKey: lastInviteBatchKey) as? Date }
        set { defaults.set(newValue, forKey: lastInviteBatchKey) }
    }

    // App Store URL
    static let appStoreURL = URL(string: "https://apps.apple.com/app/stattie/id6738968579")!

    init() {
        invitesSent = defaults.integer(forKey: invitesSentKey)
        invitesAccepted = defaults.integer(forKey: invitesAcceptedKey)
        pendingInvites = Self.loadPendingInvites(from: defaults)
    }

    // MARK: - Invite Messages

    func teamInviteMessage(teamName: String, playerCount: Int) -> String {
        """
        Hey! I'm using Stattie to track stats for \(teamName) (\(playerCount) players).

        Join as a parent or coach to:
        • View live game stats
        • Record games together
        • See performance trends

        Download free: \(Self.appStoreURL.absoluteString)

        It's the easiest way to track youth sports stats!
        """
    }

    func quickTeamInvite(teamName: String) -> String {
        "Join me on Stattie to track \(teamName)'s game stats! Download free: \(Self.appStoreURL.absoluteString)"
    }

    func coachInviteMessage(teamName: String) -> String {
        """
        Coach - I'm using Stattie to track stats for \(teamName).

        As a coach, you can:
        • Track stats during games with one tap
        • View team and player performance trends
        • Share game summaries with parents

        Download Stattie: \(Self.appStoreURL.absoluteString)
        """
    }

    func parentInviteMessage(playerName: String, teamName: String) -> String {
        """
        Hi! I'm tracking stats for \(playerName) on \(teamName) using Stattie.

        Join to view \(playerName)'s:
        • Game-by-game stats
        • Performance trends over time
        • Live game updates

        Download free: \(Self.appStoreURL.absoluteString)
        """
    }

    // MARK: - Batch Invite

    func sendBatchInvite(
        teamName: String,
        playerCount: Int,
        contacts: [InviteContact],
        from viewController: UIViewController? = nil
    ) {
        let message = teamInviteMessage(teamName: teamName, playerCount: playerCount)

        // Track each invite
        for contact in contacts {
            let pending = PendingInvite(
                id: UUID(),
                name: contact.name,
                contactInfo: contact.phoneOrEmail,
                teamName: teamName,
                sentAt: Date()
            )
            pendingInvites.append(pending)
        }

        invitesSent += contacts.count
        lastInviteBatchDate = Date()

        // Show share sheet
        shareMessage(message, from: viewController)

        // Unlock achievement
        checkInviteAchievements()
    }

    func sendSingleInvite(
        message: String,
        contactName: String,
        teamName: String,
        from viewController: UIViewController? = nil
    ) {
        let pending = PendingInvite(
            id: UUID(),
            name: contactName,
            contactInfo: nil,
            teamName: teamName,
            sentAt: Date()
        )
        pendingInvites.append(pending)

        invitesSent += 1

        shareMessage(message, from: viewController)
        checkInviteAchievements()
    }

    private func shareMessage(_ message: String, from viewController: UIViewController?) {
        let items: [Any] = [message]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let vc = viewController {
            vc.present(activityVC, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Achievements

    private func checkInviteAchievements() {
        // First invite
        if invitesSent == 1 {
            _ = AchievementManager.shared.unlock(.firstShare)
        }

        // Team builder - invited 5+ people
        if invitesSent >= 5 {
            _ = AchievementManager.shared.unlock(.teamBuilder)
        }

        // Viral champion - 3+ people joined from invites
        if invitesAccepted >= 3 {
            _ = AchievementManager.shared.unlock(.viralChampion)
        }
    }

    // Called when someone joins from an invite - also checks achievements
    func checkViralAchievements() {
        if invitesAccepted >= 3 {
            _ = AchievementManager.shared.unlock(.viralChampion)
        }
    }

    // MARK: - Viral Metrics

    var viralCoefficient: Double {
        guard invitesSent > 0 else { return 0 }
        return Double(invitesAccepted) / Double(invitesSent)
    }

    var inviteConversionRate: String {
        guard invitesSent > 0 else { return "0%" }
        let rate = (Double(invitesAccepted) / Double(invitesSent)) * 100
        return String(format: "%.0f%%", rate)
    }

    // MARK: - Persistence

    private func savePendingInvites() {
        if let data = try? JSONEncoder().encode(pendingInvites) {
            defaults.set(data, forKey: pendingInvitesKey)
        }
    }

    private static func loadPendingInvites(from defaults: UserDefaults) -> [PendingInvite] {
        guard let data = defaults.data(forKey: "pendingTeamInvites"),
              let invites = try? JSONDecoder().decode([PendingInvite].self, from: data) else {
            return []
        }
        return invites
    }

    // Track when someone joins (would be called from deep link handling)
    func markInviteAccepted(contactInfo: String?) {
        if let info = contactInfo,
           let index = pendingInvites.firstIndex(where: { $0.contactInfo == info }) {
            pendingInvites.remove(at: index)
        }
        invitesAccepted += 1

        // Check for viral achievements
        checkViralAchievements()
    }
}

// MARK: - Models

struct PendingInvite: Codable, Identifiable {
    let id: UUID
    let name: String
    let contactInfo: String?
    let teamName: String
    let sentAt: Date

    var daysSinceSent: Int {
        Calendar.current.dateComponents([.day], from: sentAt, to: Date()).day ?? 0
    }
}

struct InviteContact: Identifiable {
    let id = UUID()
    let name: String
    let phoneOrEmail: String?
    var isSelected: Bool = false
}

// MARK: - Contact Role

enum InviteRole: String, CaseIterable {
    case parent = "Parent"
    case coach = "Coach"
    case family = "Family Member"
    case other = "Other"

    var icon: String {
        switch self {
        case .parent: return "figure.2.and.child.holdinghands"
        case .coach: return "whistle.fill"
        case .family: return "person.3.fill"
        case .other: return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .parent: return .blue
        case .coach: return .green
        case .family: return .purple
        case .other: return .gray
        }
    }
}
