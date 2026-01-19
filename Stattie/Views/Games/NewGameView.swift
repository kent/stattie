import SwiftUI
import SwiftData

struct NewGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Player.jerseyNumber) private var players: [Player]
    @Query private var users: [User]
    @Query(filter: #Predicate<Sport> { $0.name == "Basketball" }) private var sports: [Sport]

    @State private var opponent = ""
    @State private var location = ""
    @State private var gameDate = Date()
    @State private var selectedPlayers: Set<UUID> = []
    @State private var notes = ""

    // Quick add player fields
    @State private var quickAddName = ""
    @State private var quickAddNumber = ""
    @State private var showingQuickAdd = false

    private var currentUser: User? {
        users.first
    }

    private var basketball: Sport? {
        sports.first
    }

    private var activePlayers: [Player] {
        players.filter { $0.isActive }.sorted { $0.jerseyNumber < $1.jerseyNumber }
    }

    private var isValid: Bool {
        !selectedPlayers.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Details") {
                    TextField("Opponent (optional)", text: $opponent)
                    TextField("Location (optional)", text: $location)
                    DatePicker("Date & Time", selection: $gameDate)
                }

                Section {
                    if activePlayers.isEmpty && !showingQuickAdd {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No players yet")
                                .font(.headline)
                            Text("Add players to track their stats")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Add Players") {
                                showingQuickAdd = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    } else {
                        ForEach(activePlayers) { player in
                            Button {
                                togglePlayer(player)
                            } label: {
                                HStack {
                                    PlayerSelectionRow(player: player)
                                    Spacer()
                                    if selectedPlayers.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.accent)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("Select Players")
                        Spacer()
                        if !activePlayers.isEmpty {
                            Button(selectedPlayers.count == activePlayers.count ? "Deselect All" : "Select All") {
                                if selectedPlayers.count == activePlayers.count {
                                    selectedPlayers.removeAll()
                                } else {
                                    selectedPlayers = Set(activePlayers.map { $0.id })
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                // Quick Add Players Section
                Section {
                    if showingQuickAdd || !activePlayers.isEmpty {
                        HStack(spacing: 12) {
                            TextField("#", text: $quickAddNumber)
                                .keyboardType(.numberPad)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)

                            TextField("Player name", text: $quickAddName)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                quickAddPlayer()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(quickAddName.isEmpty && quickAddNumber.isEmpty)
                        }
                    }
                } header: {
                    if showingQuickAdd || !activePlayers.isEmpty {
                        Text("Quick Add Player")
                    }
                } footer: {
                    if showingQuickAdd || !activePlayers.isEmpty {
                        Text("Enter jersey # and/or name, then tap + to add")
                    }
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Game") {
                        createGame()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func togglePlayer(_ player: Player) {
        if selectedPlayers.contains(player.id) {
            selectedPlayers.remove(player.id)
        } else {
            selectedPlayers.insert(player.id)
        }
    }

    private func quickAddPlayer() {
        let name = quickAddName.trimmingCharacters(in: .whitespaces)
        let number = Int(quickAddNumber) ?? 0

        guard !name.isEmpty || number > 0 else { return }

        // Split name into first/last
        let nameParts = name.split(separator: " ", maxSplits: 1)
        let firstName = nameParts.first.map(String.init) ?? ""
        let lastName = nameParts.count > 1 ? String(nameParts[1]) : ""

        let player = Player(
            firstName: firstName,
            lastName: lastName,
            jerseyNumber: number,
            position: "",
            isActive: true,
            owner: currentUser
        )

        modelContext.insert(player)
        try? modelContext.save()

        // Auto-select the new player
        selectedPlayers.insert(player.id)

        // Clear fields
        quickAddName = ""
        quickAddNumber = ""
    }

    private func createGame() {
        let game = Game(
            gameDate: gameDate,
            opponent: opponent.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            isCompleted: false,
            sport: basketball,
            trackedBy: currentUser
        )

        modelContext.insert(game)

        for player in activePlayers where selectedPlayers.contains(player.id) {
            let playerStats = PlayerGameStats(player: player, game: game)
            modelContext.insert(playerStats)

            if game.playerStats == nil {
                game.playerStats = []
            }
            game.playerStats?.append(playerStats)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct PlayerSelectionRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Text("#\(player.jerseyNumber)")
                    .font(.caption.bold())
                    .foregroundStyle(.accent)
            }

            Text(player.fullName)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NewGameView()
        .modelContainer(for: [Game.self, Player.self, User.self, Sport.self], inMemory: true)
}
