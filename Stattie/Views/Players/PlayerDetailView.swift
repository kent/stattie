import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PlayerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Player

    @Query private var users: [User]
    @Query(filter: #Predicate<Sport> { $0.name == "Basketball" }) private var sports: [Sport]

    @State private var isEditing = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showShareSheet = false
    @State private var showManageSharing = false
    @State private var isShared = false
    @State private var isOwner = true
    @State private var showingNewGame = false
    @State private var activeGame: Game?
    @State private var gameCountBeforeNew = 0

    private var currentUser: User? { users.first }
    private var basketball: Sport? { sports.first }

    // Get player's games sorted by date
    private var playerGames: [PlayerGameStats] {
        (player.gameStats ?? [])
            .sorted { ($0.game?.gameDate ?? .distantPast) > ($1.game?.gameDate ?? .distantPast) }
    }

    private var activeGames: [PlayerGameStats] {
        playerGames.filter { $0.game?.isCompleted == false }
    }

    private var completedGames: [PlayerGameStats] {
        playerGames.filter { $0.game?.isCompleted == true }
    }

    var body: some View {
        List {
            // Player Header
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let photoData = player.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 100, height: 100)

                                VStack {
                                    Image(systemName: "camera")
                                        .font(.title2)
                                    Text("Add Photo")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.accent)
                            }
                        }
                    }
                    .disabled(!isEditing)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // Player Info
            Section("Player Info") {
                if isEditing {
                    TextField("First Name", text: $player.firstName)
                    TextField("Last Name", text: $player.lastName)
                    HStack {
                        Text("Jersey Number")
                        Spacer()
                        TextField("", value: $player.jerseyNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    TextField("Position", text: $player.position)
                } else {
                    LabeledContent("Name", value: player.fullName)
                    LabeledContent("Jersey", value: "#\(player.jerseyNumber)")
                    if !player.position.isEmpty {
                        LabeledContent("Position", value: player.position)
                    }
                }
            }

            // Actions
            if !isEditing {
                Section {
                    Button {
                        startNewGame()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Record New Game", systemImage: "plus.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                }

                if !playerGames.isEmpty {
                    Section {
                        NavigationLink {
                            PlayerStatsOverTimeView(player: player)
                        } label: {
                            Label("View Stats & Trends", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }

                // Active Games
                if !activeGames.isEmpty {
                    Section("Active Games") {
                        ForEach(activeGames) { pgs in
                            if let game = pgs.game {
                                Button {
                                    activeGame = game
                                } label: {
                                    PlayerGameRow(game: game)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Completed Games
                if !completedGames.isEmpty {
                    Section("Completed Games") {
                        ForEach(completedGames) { pgs in
                            if let game = pgs.game {
                                NavigationLink(value: game) {
                                    PlayerGameRow(game: game)
                                }
                            }
                        }
                    }
                }

                // Empty State
                if playerGames.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Games Yet", systemImage: "sportscourt")
                        } description: {
                            Text("Record a game to start tracking stats")
                        }
                    }
                }
            }
        }
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Menu {
                        if isShared {
                            Button {
                                showManageSharing = true
                            } label: {
                                Label("Manage Sharing...", systemImage: "person.2")
                            }
                        } else {
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share Player...", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            try? modelContext.save()
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            SharePlayerSheet(player: player)
        }
        .sheet(isPresented: $showManageSharing) {
            ShareManagementView(player: player)
        }
        .sheet(isPresented: $showingNewGame, onDismiss: {
            // Check if a new game was created and auto-start tracking
            if playerGames.count > gameCountBeforeNew {
                if let newestGameStats = activeGames.first, let game = newestGameStats.game {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeGame = game
                    }
                }
            }
        }) {
            NewGameForPlayerView(player: player)
        }
        .fullScreenCover(item: $activeGame) { game in
            GameTrackingView(game: game)
        }
        .task {
            await loadShareStatus()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    player.photoData = data
                    try? modelContext.save()
                }
            }
        }
    }

    private func loadShareStatus() async {
        isShared = await player.checkIsShared()
        if isShared {
            isOwner = await player.checkIsOwner()
        }
    }

    private func startNewGame() {
        gameCountBeforeNew = playerGames.count
        showingNewGame = true
    }
}

// MARK: - Player Game Row

struct PlayerGameRow: View {
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
    NavigationStack {
        PlayerDetailView(player: Player(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: Player.self, inMemory: true)
}
