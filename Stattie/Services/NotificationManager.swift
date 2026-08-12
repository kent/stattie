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
    private let streakReminderEnabledKey = "streakReminderEnabled"
    private let academyLastNotifiedGamePrefix = "academyLastNotifiedGame"

    var streakReminderEnabled: Bool {
        get { defaults.bool(forKey: streakReminderEnabledKey) }
        set { defaults.set(newValue, forKey: streakReminderEnabledKey) }
    }

    init() {
        hasRequestedPermission = defaults.bool(forKey: permissionRequestedKey)
        checkAuthorizationStatus()
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

    // MARK: - Streak Reminder

    func scheduleStreakReminder(currentStreak: Int) {
        guard isAuthorized && streakReminderEnabled && currentStreak > 0 else { return }

        // Cancel existing streak reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_reminder"])

        // Schedule for 6 PM local time
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body = "You're on a \(currentStreak)-day tracking streak. Record a game today to keep it going!"
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"

        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelStreakReminder() {
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

    // MARK: - Academy Notifications

    func sendAcademyPlanReadyNotification(
        playerName: String,
        playerID: UUID,
        gameID: UUID,
        topFocusTitle: String?
    ) {
        let key = "\(academyLastNotifiedGamePrefix).\(playerID.uuidString)"
        if defaults.string(forKey: key) == gameID.uuidString {
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let status = settings.authorizationStatus
            guard status == .authorized || status == .provisional || status == .ephemeral else {
                return
            }

            let cleanPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = cleanPlayerName.isEmpty ? "Player" : cleanPlayerName

            let content = UNMutableNotificationContent()
            content.title = "Academy update ready"
            if let topFocusTitle, !topFocusTitle.isEmpty {
                content.body = "\(resolvedName): \(topFocusTitle). Open Academy to review this player's latest priorities."
            } else {
                content.body = "\(resolvedName)'s latest priorities are ready. Open Academy to review."
            }
            content.sound = .default
            content.categoryIdentifier = "ACADEMY_READY"
            content.threadIdentifier = "academy_updates"
            content.userInfo = [
                "destination": "academy",
                "playerID": playerID.uuidString,
                "gameID": gameID.uuidString
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            let identifier = "academy_ready.\(gameID.uuidString).\(playerID.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if error == nil {
                    self.defaults.set(gameID.uuidString, forKey: key)
                }
            }
        }
    }
}

// MARK: - Notification Permission View

struct NotificationPermissionCard: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingSettings = false

    var body: some View {
        if !notificationManager.hasRequestedPermission || (!notificationManager.isAuthorized && notificationManager.hasRequestedPermission) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stay on Track")
                            .font(.headline)
                        Text("Get reminders to keep your streak going")
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
}

// MARK: - Streak Reminder Toggle

struct StreakReminderToggle: View {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        if notificationManager.isAuthorized {
            Toggle(isOn: Binding(
                get: { notificationManager.streakReminderEnabled },
                set: { newValue in
                    notificationManager.streakReminderEnabled = newValue
                    if !newValue {
                        notificationManager.cancelStreakReminder()
                    }
                }
            )) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.blue)
                    Text("Daily Streak Reminder")
                }
            }
        }
    }
}
