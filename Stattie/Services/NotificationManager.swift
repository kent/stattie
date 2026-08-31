import Foundation
import UserNotifications
import SwiftUI
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var hasRequestedPermission = false

    private let defaults = UserDefaults.standard
    private let permissionRequestedKey = "notificationPermissionRequested"

    var needsPermissionPrompt: Bool {
        !hasRequestedPermission || (!isAuthorized && hasRequestedPermission)
    }

    init() {
        hasRequestedPermission = defaults.bool(forKey: permissionRequestedKey)
        checkAuthorizationStatus()
        cancelLegacyStreakReminders()
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestPermission() async -> Bool {
        defaults.set(true, forKey: permissionRequestedKey)
        hasRequestedPermission = true

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            return false
        }
    }

    /// Clears daily streak reminders scheduled by earlier app versions.
    func cancelLegacyStreakReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_reminder"])
    }

    // MARK: - Achievement Notifications

    func sendAchievementNotification(title: String, subtitle: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked! 🏆"
        content.body = "\(title) - \(subtitle)"
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Game Milestone Notifications

    func scheduleGameMilestoneCheck(gamesCount: Int) {
        // Notify at milestone game counts
        let milestones = [5, 10, 25, 50, 100, 250, 500]
        let nextMilestone = milestones.first { $0 > gamesCount }

        guard let milestone = nextMilestone, isAuthorized else { return }

        let gamesNeeded = milestone - gamesCount

        // Store for later celebration
        defaults.set(milestone, forKey: "nextGameMilestone")
        defaults.set(gamesNeeded, forKey: "gamesUntilMilestone")
    }
}

// MARK: - Notification Permission View

struct NotificationsPromptSection: View {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        if notificationManager.needsPermissionPrompt {
            Section {
                NotificationPermissionCard()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }
}

struct NotificationPermissionCard: View {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stay in the Loop")
                        .font(.headline)
                    Text("Get notified when you unlock a badge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if notificationManager.hasRequestedPermission && !notificationManager.isAuthorized {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Enable in Settings")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Button {
                    Task {
                        await notificationManager.requestPermission()
                    }
                } label: {
                    Text("Enable Notifications")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
