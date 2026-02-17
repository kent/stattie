import SwiftUI
import SwiftData

struct GameListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.gameDate, order: .reverse) private var games: [Game]
    @State private var showingNewGame = false
    @State private var selectedGame: Game?
    @State private var editingGame: Game?
    @State private var gamePendingDelete: Game?
    @State private var showingDeleteConfirmation = false
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
                                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                            Button {
                                                editingGame = game
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                confirmDelete(game)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        if !completedGames.isEmpty {
                            Section("Completed") {
                                ForEach(completedGames) { game in
                                    NavigationLink(value: game) {
                                        GameRowView(game: game)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            editingGame = game
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            confirmDelete(game)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
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
            .sheet(item: $editingGame) { game in
                EditGameSheetView(game: game)
            }
            .fullScreenCover(item: $selectedGame) { game in
                GameTrackingView(game: game)
            }
            .alert("Delete Game?", isPresented: $showingDeleteConfirmation, presenting: gamePendingDelete) { game in
                Button("Delete", role: .destructive) {
                    deleteGame(game)
                }
                Button("Cancel", role: .cancel) {
                    gamePendingDelete = nil
                }
            } message: { _ in
                Text("This will permanently remove the game and all tracked stats.")
            }
        }
    }

    private func confirmDelete(_ game: Game) {
        gamePendingDelete = game
        showingDeleteConfirmation = true
    }

    private func deleteGame(_ game: Game) {
        modelContext.delete(game)
        try? modelContext.save()
        gamePendingDelete = nil
    }
}

struct GameRowView: View {
    let game: Game

    private var metadataText: String {
        var parts: [String] = []
        if let teamName = game.team?.name, !teamName.isEmpty {
            parts.append(teamName)
        }
        if let sportName = game.sport?.name, !sportName.isEmpty {
            parts.append(sportName)
        }
        return parts.joined(separator: " • ")
    }

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

                if !metadataText.isEmpty {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

struct EditGameSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game

    @State private var opponent: String
    @State private var location: String
    @State private var gameDate: Date
    @State private var notes: String
    @State private var isCompleted: Bool

    init(game: Game) {
        self.game = game
        _opponent = State(initialValue: game.opponent)
        _location = State(initialValue: game.location)
        _gameDate = State(initialValue: game.gameDate)
        _notes = State(initialValue: game.notes)
        _isCompleted = State(initialValue: game.isCompleted)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Details") {
                    TextField("Opponent (optional)", text: $opponent)
                    TextField("Location (optional)", text: $location)
                    DatePicker("Date & Time", selection: $gameDate)
                    Toggle("Completed", isOn: $isCompleted)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        game.opponent = opponent.trimmingCharacters(in: .whitespaces)
        game.location = location.trimmingCharacters(in: .whitespaces)
        game.gameDate = gameDate
        game.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        game.isCompleted = isCompleted

        try? modelContext.save()
        dismiss()
    }
}
