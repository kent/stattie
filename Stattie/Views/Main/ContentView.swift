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
            AchievementManager.shared.synchronizeFromCloud(force: true)
            LocalCoachingService.shared.bootstrapCloudCacheIfNeeded()
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

            TeamListView()
                .tabItem {
                    Label("Teams", systemImage: "person.3.fill")
                }
                .tag(AppState.MainTab.teams.rawValue)

            NavigationStack {
                RecentActivityView()
            }
            .tabItem {
                Label("Activity", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppState.MainTab.activity.rawValue)

            AcademyView()
                .tabItem {
                    Label("Academy", systemImage: "graduationcap.fill")
                }
                .tag(AppState.MainTab.academy.rawValue)

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

struct AcademyView: View {
    @Query private var users: [User]
    @Query(sort: [SortDescriptor(\Person.lastName), SortDescriptor(\Person.firstName)])
    private var allPlayers: [Person]
    @State private var path = NavigationPath()
    @State private var appState = AppState.shared
    @State private var isRefreshingAcademy = false
    @State private var refreshCompletedCount = 0
    @State private var refreshTotalCount = 0
    @State private var lastRefreshAt: Date?

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    private var activePlayers: [Person] {
        allPlayers.filter { $0.isActive && $0.isOwned(by: currentUser) }
    }

    private var refreshProgress: Double {
        guard refreshTotalCount > 0 else { return 0 }
        return min(1, max(0, Double(refreshCompletedCount) / Double(refreshTotalCount)))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !activePlayers.isEmpty {
                    Section("Academy Refresh") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Rebuild from last \(LocalCoachingService.shared.academyStatsWindow) completed games")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Refreshes every player's priorities on this device using current trend data.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            Button {
                                Task {
                                    await refreshAcademyFromRecentGames()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isRefreshingAcademy {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(isRefreshingAcademy ? "Refreshing Academy..." : "Refresh Academy")
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRefreshingAcademy)

                            if isRefreshingAcademy || lastRefreshAt != nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    ProgressView(value: refreshProgress, total: 1.0)
                                        .tint(.blue)

                                    HStack {
                                        Text(isRefreshingAcademy
                                             ? "Updated \(refreshCompletedCount) of \(refreshTotalCount) players"
                                             : "Updated \(refreshCompletedCount) of \(refreshTotalCount) players")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let lastRefreshAt, !isRefreshingAcademy {
                                        Text("Last refresh \(lastRefreshAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if activePlayers.isEmpty {
                    ContentUnavailableView(
                        "No Players Yet",
                        systemImage: "graduationcap",
                        description: Text("Add players to unlock position-aware practice priorities.")
                    )
                } else {
                    ForEach(activePlayers) { player in
                        NavigationLink(value: player.id) {
                            AcademyPlayerRow(player: player)
                        }
                    }
                }
            }
            .navigationTitle("Academy")
            .navigationDestination(for: UUID.self) { playerID in
                if let player = activePlayers.first(where: { $0.id == playerID }) {
                    AcademyPlayerPlanView(player: player)
                } else {
                    ContentUnavailableView(
                        "Player Not Found",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("This player is no longer available in your Academy list.")
                    )
                }
            }
            .onAppear {
                openPendingAcademyPlayerIfNeeded()
            }
            .onChange(of: appState.pendingAcademyPlayerID) { _, _ in
                openPendingAcademyPlayerIfNeeded()
            }
            .onChange(of: activePlayers.map(\.id)) { _, _ in
                openPendingAcademyPlayerIfNeeded()
            }
        }
    }

    private func openPendingAcademyPlayerIfNeeded() {
        guard appState.selectedTab == .academy else { return }
        guard let pendingPlayerID = appState.pendingAcademyPlayerID else { return }
        guard activePlayers.contains(where: { $0.id == pendingPlayerID }) else { return }

        path = NavigationPath()
        path.append(pendingPlayerID)
        appState.pendingAcademyPlayerID = nil
    }

    @MainActor
    private func refreshAcademyFromRecentGames() async {
        guard !isRefreshingAcademy else { return }
        let players = activePlayers
        guard !players.isEmpty else { return }

        isRefreshingAcademy = true
        refreshTotalCount = players.count
        refreshCompletedCount = 0

        for player in players {
            _ = await LocalCoachingService.shared.generateAndCacheAcademyPlan(
                for: player,
                sourceGameID: nil,
                forceRefresh: true
            )
            refreshCompletedCount += 1
        }

        lastRefreshAt = Date()
        isRefreshingAcademy = false
    }
}

private struct AcademyPlayerRow: View {
    let player: Person

    private var focusItems: [CoachingFocusItem] {
        let todos = LocalCoachingService.shared.academyTodoFocusItems(for: player)
        if !todos.isEmpty {
            return todos
        }

        if let cached = LocalCoachingService.shared.cachedAcademyPlan(for: player) {
            return cached.focusItems.sorted { $0.rank < $1.rank }
        }

        return LocalCoachingService.shared.localAcademyPlan(for: player).focusItems.sorted { $0.rank < $1.rank }
    }

    private var positionText: String {
        let memberships = (player.teamMemberships ?? []).filter(\.isActive)
        if let membershipPosition = memberships.first?.positionDisplayText, !membershipPosition.isEmpty {
            return membershipPosition
        }
        if !player.positionDisplayText.isEmpty {
            return player.positionDisplayText
        }
        return "Position not set"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(player.displayName)
                    .font(.headline)
                Spacer()
                Text(positionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(focusItems) { item in
                Text("\(item.rank). \(item.title)\(item.confirmationCount > 1 ? " • x\(item.confirmationCount)" : "")")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AcademyPlayerPlanView: View {
    let player: Person

    @State private var coachingPlan: CoachingInsightReport?
    @State private var todoItems: [CoachingFocusItem] = []
    @State private var isRefreshingPlan = false

    private var localPlan: CoachingInsightReport {
        LocalCoachingService.shared.localAcademyPlan(for: player)
    }

    private var displayedPlan: CoachingInsightReport {
        coachingPlan ?? localPlan
    }

    private var displayedFocusItems: [CoachingFocusItem] {
        if !todoItems.isEmpty {
            return todoItems.sorted { $0.rank < $1.rank }
        }
        return displayedPlan.focusItems.sorted { $0.rank < $1.rank }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(player.displayName)
                            .font(.headline)
                        Spacer()
                        Text(displayedPlan.source.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Text(displayedPlan.headline)
                        .font(.subheadline.weight(.semibold))

                    Text(displayedPlan.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section(todoItems.isEmpty ? "Prioritized Focus" : "Live Todo Priorities") {
                ForEach(displayedFocusItems) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text("\(item.rank)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.headline)
                                    if item.confirmationCount > 1 {
                                        Text("Confirmed x\(item.confirmationCount)")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(item.whyItMatters)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(item.actionPlan)
                            .font(.subheadline)

                        if !item.resources.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Free Resources")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                ForEach(item.resources) { resource in
                                    Link(destination: resource.url) {
                                        Label(resource.title, systemImage: "link")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Player Academy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isRefreshingPlan {
                    ProgressView()
                } else {
                    Button("Refresh Plan") {
                        Task {
                            await refreshPlan()
                        }
                    }
                }
            }
        }
        .task {
            coachingPlan = LocalCoachingService.shared.cachedAcademyPlan(for: player)
            todoItems = LocalCoachingService.shared.academyTodoFocusItems(for: player)
        }
    }

    private func refreshPlan() async {
        isRefreshingPlan = true
        coachingPlan = await LocalCoachingService.shared.generateAndCacheAcademyPlan(
            for: player,
            sourceGameID: nil,
            forceRefresh: true
        )
        todoItems = LocalCoachingService.shared.academyTodoFocusItems(for: player)
        isRefreshingPlan = false
    }
}

#Preview {
    AcademyView()
        .modelContainer(for: [Person.self, TeamMembership.self, Game.self, PersonGameStats.self, Stat.self, Shift.self, ShiftStat.self], inMemory: true)
}
