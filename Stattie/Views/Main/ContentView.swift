import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var users: [User]

    var hasCompletedOnboarding: Bool {
        !users.isEmpty
    }

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView {
                // Onboarding complete - view will refresh automatically
            }
        }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            PersonListView()
                .tabItem {
                    Label("Players", systemImage: "person.fill")
                }

            TeamListView()
                .tabItem {
                    Label("Teams", systemImage: "person.3.fill")
                }

            NavigationStack {
                RecentActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            // Ensure all sports are seeded (for existing users who may not have all sports)
            SeedDataService.shared.seedAllSportsIfNeeded(context: modelContext)
            // Seed test player for development
            SeedDataService.shared.seedJackJamesIfNeeded(context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [User.self, Person.self, Game.self, Sport.self, StatDefinition.self], inMemory: true)
}
