import SwiftUI
import SwiftData
import UIKit

/// Simplified new game view for creating a game for a specific player
struct NewGameForPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player

    @Query private var users: [User]
    @Query(filter: #Predicate<Sport> { $0.name == "Basketball" }) private var sports: [Sport]

    @State private var opponent = ""
    @State private var location = ""
    @State private var gameDate = Date()

    private var currentUser: User? { users.first }
    private var basketball: Sport? { sports.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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

                        VStack(alignment: .leading) {
                            Text(player.fullName)
                                .font(.headline)
                            if !player.position.isEmpty {
                                Text(player.position)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Player")
                }

                Section("Game Details") {
                    TextField("Opponent (optional)", text: $opponent)
                    TextField("Location (optional)", text: $location)
                    DatePicker("Date & Time", selection: $gameDate)
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
                }
            }
        }
    }

    private func createGame() {
        let game = Game(
            gameDate: gameDate,
            opponent: opponent.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            notes: "",
            isCompleted: false,
            sport: basketball,
            trackedBy: currentUser
        )

        modelContext.insert(game)

        // Create player stats for this game
        let playerStats = PlayerGameStats(player: player, game: game)
        modelContext.insert(playerStats)

        if game.playerStats == nil {
            game.playerStats = []
        }
        game.playerStats?.append(playerStats)

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NewGameForPlayerView(player: Player(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
        .modelContainer(for: [Game.self, Player.self, User.self, Sport.self], inMemory: true)
}
