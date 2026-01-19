import SwiftUI
import SwiftData

struct GameListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.gameDate, order: .reverse) private var games: [Game]
    @State private var showingNewGame = false
    @State private var selectedGame: Game?
    @State private var gameCountBeforeNew = 0

    var activeGames: [Game] {
        games.filter { !$0.isCompleted }
    }

    var completedGames: [Game] {
        games.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            Group {
                if games.isEmpty {
                    ContentUnavailableView {
                        Label("No Games", systemImage: "sportscourt")
                    } description: {
                        Text("Start a new game to track player stats")
                    } actions: {
                        Button("New Game") {
                            gameCountBeforeNew = games.count
                            showingNewGame = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !activeGames.isEmpty {
                            Section("Active Games") {
                                ForEach(activeGames) { game in
                                    GameRowView(game: game)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedGame = game
                                        }
                                }
                                .onDelete(perform: deleteActiveGame)
                            }
                        }

                        if !completedGames.isEmpty {
                            Section("Completed") {
                                ForEach(completedGames) { game in
                                    NavigationLink(value: game) {
                                        GameRowView(game: game)
                                    }
                                }
                                .onDelete(perform: deleteCompletedGame)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Games")
            .navigationDestination(for: Game.self) { game in
                GameDetailView(game: game)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        gameCountBeforeNew = games.count
                        showingNewGame = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewGame, onDismiss: {
                // Check if a new game was created
                if games.count > gameCountBeforeNew {
                    // Find the newest active game and start tracking
                    if let newestGame = activeGames.first {
                        // Small delay to let sheet fully dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedGame = newestGame
                        }
                    }
                }
            }) {
                NewGameView()
            }
            .fullScreenCover(item: $selectedGame) { game in
                GameTrackingView(game: game)
            }
        }
    }

    private func deleteActiveGame(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(activeGames[index])
        }
        try? modelContext.save()
    }

    private func deleteCompletedGame(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(completedGames[index])
        }
        try? modelContext.save()
    }
}

struct GameRowView: View {
    let game: Game

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if game.opponent.isEmpty {
                        Text("Game")
                            .font(.headline)
                    } else {
                        Text("vs \(game.opponent)")
                            .font(.headline)
                    }

                    if game.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text(game.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !game.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(game.location)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(game.totalPoints)")
                    .font(.title2.bold())
                    .foregroundStyle(.accent)

                Text("points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GameListView()
        .modelContainer(for: Game.self, inMemory: true)
}
