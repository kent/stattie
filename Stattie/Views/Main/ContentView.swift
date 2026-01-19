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
    var body: some View {
        TabView {
            GameListView()
                .tabItem {
                    Label("Games", systemImage: "sportscourt")
                }

            PlayerListView()
                .tabItem {
                    Label("Players", systemImage: "person.3")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [User.self, Player.self, Game.self, Sport.self, StatDefinition.self], inMemory: true)
}
