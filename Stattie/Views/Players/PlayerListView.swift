import SwiftUI
import SwiftData
import UIKit

struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.jerseyNumber) private var players: [Player]
    @State private var showingAddPlayer = false
    @State private var searchText = ""

    var filteredPlayers: [Player] {
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
                if filteredPlayers.isEmpty {
                    ContentUnavailableView {
                        Label("No Players", systemImage: "person.3")
                    } description: {
                        Text("Add players to start tracking their stats")
                    } actions: {
                        Button("Add Player") {
                            showingAddPlayer = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(filteredPlayers) { player in
                            NavigationLink(value: player) {
                                PlayerRowView(player: player)
                            }
                        }
                        .onDelete(perform: deletePlayer)
                    }
                }
            }
            .navigationTitle("Players")
            .navigationDestination(for: Player.self) { player in
                PlayerDetailView(player: player)
            }
            .searchable(text: $searchText, prompt: "Search players")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                AddPlayerView()
            }
        }
    }

    private func deletePlayer(at offsets: IndexSet) {
        for index in offsets {
            let player = filteredPlayers[index]
            player.isActive = false
        }
        try? modelContext.save()
    }
}

struct PlayerRowView: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                if let photoData = player.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text("#\(player.jerseyNumber)")
                        .font(.headline)
                        .foregroundStyle(.accent)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.fullName)
                        .font(.headline)
                    AsyncSharedPlayerBadge(player: player)
                }

                if !player.position.isEmpty {
                    Text(player.position)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlayerListView()
        .modelContainer(for: Player.self, inMemory: true)
}
