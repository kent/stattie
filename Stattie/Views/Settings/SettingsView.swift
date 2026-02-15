import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query private var users: [User]
    @Query private var players: [Person]
    @Query private var games: [Game]
    @State private var syncManager = SyncManager.shared

    @State private var isEditingName = false
    @State private var editedName = ""

    private var currentUser: User? {
        users.first
    }

    private var activePlayers: Int {
        players.filter { $0.isActive }.count
    }

    private var completedGames: Int {
        games.filter { $0.isCompleted }.count
    }

    private var totalPointsTracked: Int {
        games.filter { $0.isCompleted }.reduce(0) { $0 + $1.totalPoints }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    if let user = currentUser {
                        if isEditingName {
                            HStack {
                                TextField("Display Name", text: $editedName)
                                    .textContentType(.name)

                                Button("Save") {
                                    saveDisplayName()
                                }
                                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        } else {
                            HStack {
                                Text("Display Name")
                                Spacer()
                                Text(user.displayName)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editedName = user.displayName
                                isEditingName = true
                            }
                        }

                        LabeledContent("Member Since") {
                            Text(user.createdAt, style: .date)
                        }
                    }
                }

                Section {
                    HStack {
                        Label("iCloud Status", systemImage: "icloud")
                        Spacer()
                        if syncManager.isCheckingStatus {
                            ProgressView()
                        } else {
                            Text(syncManager.statusDescription)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if syncManager.isSignedIntoiCloud {
                        if let lastSync = syncManager.lastSyncDate {
                            LabeledContent("Last Sync") {
                                Text(lastSync, style: .relative)
                            }
                        }
                    } else {
                        Text("Sign in to iCloud in Settings to sync data across devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Your data is stored locally and optionally synced via iCloud")
                }

                // Streak Section
                if let user = currentUser, user.currentStreak > 0 {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(.orange)
                                    Text("\(user.currentStreak) day streak!")
                                        .font(.headline)
                                }

                                if user.streakAtRisk {
                                    Text("Track a game today to keep it going!")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("Longest: \(user.longestStreak) days")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("🔥")
                                .font(.largeTitle)
                        }
                    }
                }

                // Notifications
                Section {
                    StreakReminderToggle()
                    NotificationPermissionCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Achievements
                Section {
                    NavigationLink {
                        AchievementsView()
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Achievements")
                                    .font(.body)
                                Text("\(AchievementManager.shared.unlockedAchievements.count)/\(AchievementType.allCases.count) unlocked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(AchievementManager.shared.totalPoints) pts")
                                .font(.subheadline.bold())
                                .foregroundStyle(.accent)
                        }
                    }
                }

                // Stats Summary
                Section("Your Stats") {
                    HStack(spacing: 16) {
                        StatsSummaryPill(value: activePlayers, label: "Players", icon: "person.3.fill", color: .blue)
                        StatsSummaryPill(value: completedGames, label: "Games", icon: "sportscourt.fill", color: .green)
                        StatsSummaryPill(value: totalPointsTracked, label: "Points", icon: "flame.fill", color: .orange)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")

                    Link(destination: URL(string: "https://stattie.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: "https://stattie.app/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }

                // Invite Friends
                InviteFriendsSection()

                Section {
                    Link(destination: URL(string: "mailto:support@stattie.app")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }

                    Button {
                        requestReview()
                    } label: {
                        Label("Rate Stattie", systemImage: "star.fill")
                    }

                    Button {
                        shareApp()
                    } label: {
                        Label("Share Stattie", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await syncManager.checkiCloudStatus()
            }
        }
    }

    private func saveDisplayName() {
        guard let user = currentUser else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        user.displayName = trimmed
        try? modelContext.save()
        isEditingName = false
    }

    private func shareApp() {
        let text = "I'm using Stattie to track game stats for my players! Check it out:"
        let url = URL(string: "https://apps.apple.com/app/stattie/id0")!

        let activityVC = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct StatsSummaryPill: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(value)")
                .font(.title2.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: User.self, inMemory: true)
}
