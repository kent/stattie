import SwiftUI
import SwiftData
import UIKit

struct PersonListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.firstName) private var players: [Person]
    @Query private var users: [User]
    @State private var showingAddPerson = false
    @State private var searchText = ""

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    private var ownedActivePlayers: [Person] {
        players.filter { $0.isActive && $0.isOwned(by: currentUser) }
    }

    var filteredPersons: [Person] {
        let filtered: [Person]
        if searchText.isEmpty {
            filtered = ownedActivePlayers
        } else {
            filtered = ownedActivePlayers.filter { player in
                (
                    player.firstName.localizedCaseInsensitiveContains(searchText) ||
                    player.lastName.localizedCaseInsensitiveContains(searchText)
                )
            }
        }

        return filtered.sorted { lhs, rhs in
            lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredPersons.isEmpty {
                    VStack(spacing: 24) {
                        ContentUnavailableView {
                            Label("No Players Yet", systemImage: "person.3.fill")
                        } description: {
                            Text("Add your first player to start tracking their game stats and performance")
                        } actions: {
                            Button("Add Player") {
                                showingAddPerson = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        // Getting started tips
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Getting Started")
                                .font(.headline)
                                .padding(.horizontal)

                            TipCard(
                                icon: "person.badge.plus",
                                title: "Add a player",
                                description: "Enter their name, then assign jersey on a team"
                            )

                            TipCard(
                                icon: "sportscourt",
                                title: "Track a game",
                                description: "Tap Record New Game on any player's profile"
                            )

                            TipCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Review progress",
                                description: "Open a player to see stats and trends over time"
                            )
                        }
                        .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(filteredPersons) { player in
                            NavigationLink(value: player) {
                                PersonRowView(player: player)
                            }
                        }
                        .onDelete(perform: deletePerson)
                    }
                }
            }
            .navigationTitle("Players")
            .navigationDestination(for: Person.self) { player in
                PersonDetailView(player: player)
            }
            .searchable(text: $searchText, prompt: "Search players")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        if filteredPersons.count >= 2 {
                            NavigationLink {
                                PlayerComparisonView()
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .accessibilityLabel("Compare players")
                        }

                        Button {
                            showingAddPerson = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add player")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView()
            }
        }
    }

    private func deletePerson(at offsets: IndexSet) {
        for index in offsets {
            let player = filteredPersons[index]
            player.isActive = false
        }
        try? modelContext.save()
    }
}

struct PersonRowView: View {
    let player: Person

    private var initials: String {
        let firstInitial = player.firstName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        let lastInitial = player.lastName.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? ""
        return (firstInitial + lastInitial).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                if let photoData = player.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    if !initials.isEmpty {
                        Text(initials)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.accent)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.headline)
                            .foregroundStyle(.accent)
                    }
                }

                // Active game indicator
                if player.hasActiveGame {
                    Circle()
                        .fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 18, y: 18)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.fullName)
                        .font(.headline)
                }

                HStack(spacing: 8) {
                    if !player.position.isEmpty {
                        Text(player.positionShortText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if player.completedGamesCount > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(player.completedGamesCount) games")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Stats badge for players with games
            if player.completedGamesCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", player.averagePointsPerGame))
                        .font(.title3.bold())
                        .foregroundStyle(.accent)
                    Text("PPG")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessiblePlayerRow(
            name: player.fullName,
            jerseyNumber: player.jerseyNumber,
            gamesCount: player.completedGamesCount,
            ppg: player.averagePointsPerGame,
            hasActiveGame: player.hasActiveGame
        )
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PersonListView()
        .modelContainer(for: Person.self, inMemory: true)
}
