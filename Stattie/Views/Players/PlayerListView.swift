import SwiftUI
import SwiftData
import UIKit

struct PersonListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.jerseyNumber) private var players: [Person]
    @State private var showingAddPerson = false
    @State private var showingTeamInvite = false
    @State private var searchText = ""

    var filteredPersons: [Person] {
        if searchText.isEmpty {
            return players.filter { $0.isActive }
        }
        return players.filter { player in
            player.isActive && (
                player.firstName.localizedCaseInsensitiveContains(searchText) ||
                player.lastName.localizedCaseInsensitiveContains(searchText) ||
                "\(player.jerseyNumber)".contains(searchText)
            )
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
                                description: "Enter their name, jersey number, and position"
                            )

                            TipCard(
                                icon: "sportscourt",
                                title: "Track a game",
                                description: "Tap Record New Game on any player's profile"
                            )

                            TipCard(
                                icon: "person.2",
                                title: "Share with family",
                                description: "Coaches and parents can track games together"
                            )
                        }
                        .padding(.horizontal)
                    }
                } else {
                    List {
                        // Team invite banner (shown when 2+ players)
                        if filteredPersons.count >= 2 {
                            Section {
                                TeamInviteBanner {
                                    showingTeamInvite = true
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

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
                        }

                        Button {
                            showingAddPerson = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView()
            }
            .sheet(isPresented: $showingTeamInvite) {
                TeamInviteView(team: nil, players: filteredPersons)
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
                    Text("#\(player.jerseyNumber)")
                        .font(.headline)
                        .foregroundStyle(.accent)
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
                    AsyncSharedPersonBadge(player: player)
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

// MARK: - Team Invite Banner

struct TeamInviteBanner: View {
    let action: () -> Void
    @AppStorage("teamInviteBannerDismissed") private var isDismissed = false

    var body: some View {
        if !isDismissed {
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite Your Team")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text("Let parents & coaches track stats together")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    PersonListView()
        .modelContainer(for: Person.self, inMemory: true)
}
