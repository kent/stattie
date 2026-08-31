import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var users: [User]

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    var hasCompletedOnboarding: Bool {
        currentUser != nil
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    // Onboarding complete - view will refresh automatically
                }
            }
        }
        .onAppear {
            CloudSyncedPreferences.bootstrapIfNeeded(force: true)
            AppState.shared.synchronizeFromCloud()
            AchievementManager.shared.synchronizeFromCloud()
        }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState.shared

    var body: some View {
        TabView(selection: Binding(
            get: { appState.selectedTabRaw },
            set: { appState.selectedTabRaw = $0 }
        )) {
            PersonListView()
                .tabItem {
                    Label("Players", systemImage: "person.fill")
                }
                .tag(AppState.MainTab.players.rawValue)

            NavigationStack {
                RecentActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppState.MainTab.activity.rawValue)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppState.MainTab.settings.rawValue)
        }
        .onAppear {
            // Ensure all sports are seeded (for existing users who may not have all sports)
            SeedDataService.shared.seedAllSportsIfNeeded(context: modelContext)

            if SeedDataService.shared.shouldSeedShowcaseData {
                // Simulator screenshot data pack (teams, games, active game, trends).
                SeedDataService.shared.seedShowcaseDataIfNeeded(context: modelContext)
            } else {
                // Keep baseline historical players only when showcase seeding is disabled.
                SeedDataService.shared.seedJackJamesIfNeeded(context: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [User.self, Person.self, Game.self, Sport.self, StatDefinition.self], inMemory: true)
}
