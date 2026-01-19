import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var game: Game

    @State private var showingSummary = false
    @State private var showingTracking = false

    var sortedPlayerStats: [PlayerGameStats] {
        (game.playerStats ?? []).sorted {
            ($0.player?.jerseyNumber ?? 0) < ($1.player?.jerseyNumber ?? 0)
        }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Text("\(game.totalPoints)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.accent)

                    Text("Total Points")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }

            Section("Game Info") {
                if !game.opponent.isEmpty {
                    LabeledContent("Opponent", value: game.opponent)
                }
                LabeledContent("Date", value: game.formattedDate)
                if !game.location.isEmpty {
                    LabeledContent("Location", value: game.location)
                }
                LabeledContent("Status", value: game.isCompleted ? "Completed" : "In Progress")
            }

            Section("Player Stats") {
                ForEach(sortedPlayerStats) { pgs in
                    if let player = pgs.player {
                        PlayerStatsRow(player: player, stats: pgs)
                    }
                }
            }

            if !game.notes.isEmpty {
                Section("Notes") {
                    Text(game.notes)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if game.isCompleted {
                    Button {
                        showingSummary = true
                    } label: {
                        Label("View & Share Summary", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        showingTracking = true
                    } label: {
                        Label("Continue Tracking", systemImage: "play.fill")
                    }
                }
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game Details" : "vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSummary) {
            GameSummaryView(game: game)
        }
        .fullScreenCover(isPresented: $showingTracking) {
            GameTrackingView(game: game)
        }
    }
}

struct PlayerStatsRow: View {
    let player: Player
    let stats: PlayerGameStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(player.displayName)
                    .font(.headline)
                Spacer()
                Text("\(stats.totalPoints) pts")
                    .font(.headline)
                    .foregroundStyle(.accent)
            }

            HStack(spacing: 16) {
                ForEach(stats.stats?.filter { $0.total > 0 } ?? [], id: \.id) { stat in
                    if let def = stat.definition {
                        VStack(spacing: 2) {
                            Text(stat.displayValue)
                                .font(.subheadline.bold())
                            Text(def.shortName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: Game(opponent: "Lakers", location: "Home Gym"))
    }
    .modelContainer(for: Game.self, inMemory: true)
}
