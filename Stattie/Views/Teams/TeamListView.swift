import SwiftUI
import SwiftData

struct TeamListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.name) private var teams: [Team]
    @State private var showingAddTeam = false
    @State private var searchText = ""

    var filteredTeams: [Team] {
        if searchText.isEmpty {
            return teams.filter { $0.isActive }
        }
        return teams.filter { team in
            team.isActive && team.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredTeams.isEmpty {
                    emptyState
                } else {
                    teamList
                }
            }
            .navigationTitle("Teams")
            .navigationDestination(for: Team.self) { team in
                TeamDetailView(team: team)
            }
            .searchable(text: $searchText, prompt: "Search teams")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTeam) {
                AddTeamView()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            ContentUnavailableView {
                Label("No Teams Yet", systemImage: "person.3.fill")
            } description: {
                Text("Create a team to organize your players and track games together")
            } actions: {
                Button("Create Team") {
                    showingAddTeam = true
                }
                .buttonStyle(.borderedProminent)
            }

            // Getting started tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Getting Started")
                    .font(.headline)
                    .padding(.horizontal)

                TipCard(
                    icon: "person.3.fill",
                    title: "Create a team",
                    description: "Give your team a name and pick a sport"
                )

                TipCard(
                    icon: "person.badge.plus",
                    title: "Add players",
                    description: "Add players to your team with their positions"
                )

                TipCard(
                    icon: "sportscourt",
                    title: "Track games",
                    description: "Start a game and track stats for each player"
                )
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var teamList: some View {
        List {
            ForEach(filteredTeams) { team in
                NavigationLink(value: team) {
                    TeamRowView(team: team)
                }
            }
            .onDelete(perform: deleteTeam)
        }
    }

    private func deleteTeam(at offsets: IndexSet) {
        for index in offsets {
            let team = filteredTeams[index]
            team.isActive = false
        }
        try? modelContext.save()
    }
}

// MARK: - Team Row View

struct TeamRowView: View {
    let team: Team

    private var memberCount: Int {
        team.members.filter { $0.isActive }.count
    }

    private var gameCount: Int {
        (team.games ?? []).count
    }

    var body: some View {
        HStack(spacing: 14) {
            // Team icon
            ZStack {
                Circle()
                    .fill(Color(hex: team.colorHex))
                    .frame(width: 50, height: 50)

                Image(systemName: team.iconName.isEmpty ? "sportscourt" : team.iconName)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let sport = team.sport {
                        HStack(spacing: 4) {
                            Image(systemName: sport.iconName)
                                .font(.caption)
                            Text(sport.name)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    if memberCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                            Text("\(memberCount)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Game count badge
            if gameCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(gameCount)")
                        .font(.title3.bold())
                        .foregroundStyle(.accent)
                    Text("games")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TeamListView()
        .modelContainer(for: [Team.self, Sport.self, Person.self], inMemory: true)
}
