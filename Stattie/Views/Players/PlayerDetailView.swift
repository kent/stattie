import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var persistence = PersistenceController()
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Person

    @State private var isEditing = false
    @State private var draftFirstName = ""
    @State private var draftLastName = ""
    @State private var draftPhotoData: Data?
    @State private var draftPositions: [UUID: PositionAssignments] = [:]
    @State private var isLoadingPhoto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingNewGame = false
    @State private var showingAddToTeam = false
    @State private var activeGameStats: PersonGameStats?
    @State private var newGameTrackingLaunch: NewGameTrackingLaunch?
    @State private var gameCountBeforeNew = 0
    @State private var pendingStartingPosition: SoccerPosition?
    @State private var editingGame: Game?
    @State private var pendingGameDeletion: Game?

    private struct NewGameTrackingLaunch: Identifiable {
        let id = UUID()
        let game: Game
        let selectedPersonStatsID: UUID
        let startingPosition: SoccerPosition?
    }

    // Get player's games sorted by date
    private var playerGames: [PersonGameStats] {
        (player.gameStats ?? [])
            .sorted { ($0.game?.gameDate ?? .distantPast) > ($1.game?.gameDate ?? .distantPast) }
    }

    private var activeGames: [PersonGameStats] {
        playerGames.filter { $0.game?.isCompleted == false }
    }

    private var preferredActiveGameStats: PersonGameStats? {
        activeGames.first
    }

    private var completedGames: [PersonGameStats] {
        playerGames.filter { $0.game?.isCompleted == true }
    }

    private var playerSeasonPositionTotals: [PositionStatTotals] {
        PositionStatAggregator.seasonTotals(from: completedGames).filter { $0.position != nil }
    }

    private var playerSeasonSportName: String? {
        let names = completedGames.compactMap { $0.game?.sport?.name }
        let counted = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        return counted.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        List {
            // Player Header
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let photoData = (isEditing ? draftPhotoData : player.photoData),
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
                    .accessibilityLabel(player.photoData == nil ? "Add player photo" : "Change player photo")
                    .accessibilityHint(isEditing ? "Opens the photo library" : "Enable editing to change the photo")
                    .disabled(!isEditing)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // Player Info
            Section {
                if isEditing {
                    TextField("First Name", text: $draftFirstName)
                    TextField("Last Name", text: $draftLastName)
                } else {
                    LabeledContent("Name", value: player.fullName)
                }
            } header: {
                Text("Player Info")
            }

            if isEditing {
                Section {
                    if player.activeTeamMemberships.isEmpty {
                        Text("Add this player to a team to set sport-specific positions.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(player.activeTeamMemberships) { membership in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(membership.team?.name ?? "Team")
                                    .font(.headline)
                                Text(membership.team?.sportDisplayText ?? "No sport")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                PositionPickerView(
                                    assignments: Binding(
                                        get: { draftPositions[membership.id] ?? membership.positionAssignments },
                                        set: { draftPositions[membership.id] = $0 }
                                    ),
                                    sportName: membership.team?.sport?.name
                                )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Team Positions")
                } footer: {
                    Text("Players can have more than one position. Goalies, pitchers, and other specialist roles get different stat buttons.")
                }
            } else {
                Section {
                    if player.activeTeamMemberships.isEmpty {
                        Text("Not on a team yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(player.activeTeamMemberships) { membership in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(membership.team?.name ?? "Team")
                                    Text(membership.team?.sportDisplayText ?? "No sport")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !membership.positionDisplayText.isEmpty && membership.positionDisplayText != "No position" {
                                        Text(membership.positionDisplayText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .onDelete(perform: removeMemberships)
                    }

                    Button {
                        showingAddToTeam = true
                    } label: {
                        Label("Add to Team", systemImage: "person.badge.plus")
                    }
                } header: {
                    Text("Teams")
                } footer: {
                    Text("Players can belong to more than one team.")
                }
            }

            // Actions
            if !isEditing {
                Section {
                    Button {
                        startOrContinueGame()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                preferredActiveGameStats == nil ? "Start Game" : "Continue Game",
                                systemImage: preferredActiveGameStats == nil ? "play.circle.fill" : "arrow.right.circle.fill"
                            )
                            .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(Color.white)
                }

                if !playerGames.isEmpty {
                    Section {
                        NavigationLink {
                            PersonStatsOverTimeView(player: player)
                        } label: {
                            Label("View Stats & Trends", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }

                    if !playerSeasonPositionTotals.isEmpty {
                        Section("Season by Position") {
                            ForEach(playerSeasonPositionTotals) { totals in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Label(totals.displayName, systemImage: totals.iconName)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(totals.shiftCount) \(totals.shiftCount == 1 ? "shift" : "shifts")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(PositionStatAggregator.highlightLines(for: totals, sportName: playerSeasonSportName).map { "\($0.title) \($0.value)" }.joined(separator: "  •  "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Career Highs Section
                    if player.completedGamesCount > 0,
                       player.careerHighPoints > 0 || player.careerHighRebounds > 0 || player.careerHighAssists > 0 {
                        Section("Career Highs") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 16)], spacing: 16) {
                                CareerHighCard(value: player.careerHighPoints, label: "Points", icon: "flame.fill", color: .orange)
                                CareerHighCard(value: player.careerHighRebounds, label: "Rebounds", icon: "arrow.up.arrow.down", color: .green)
                                CareerHighCard(value: player.careerHighAssists, label: "Assists", icon: "arrow.triangle.branch", color: .blue)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        // Plus/Minus Section (if any games have shift data)
                        if player.careerPlusMinus != 0 || player.averagePlusMinus != 0 {
                            Section("Plus/Minus") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                                    PlusMinusCard(
                                        value: player.formattedCareerPlusMinus,
                                        label: "Career",
                                        plusMinus: player.careerPlusMinus
                                    )
                                    PlusMinusCard(
                                        value: String(format: "%+.1f", player.averagePlusMinus),
                                        label: "Per Game",
                                        plusMinus: Int(player.averagePlusMinus)
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }
                    }
                }

                // Active Games
                if !activeGames.isEmpty {
                    Section("Active Games") {
                        ForEach(activeGames) { pgs in
                            if let game = pgs.game {
                                Button {
                                    activeGameStats = pgs
                                } label: {
                                    PersonGameRow(game: game)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editingGame = game
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        pendingGameDeletion = game
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
                                    PersonGameRow(game: game)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editingGame = game
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        pendingGameDeletion = game
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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
        .persistenceAlert(persistence)
        .navigationTitle(player.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { savePlayerEdits() } else { beginEditing() }
                }
                .disabled(isEditing && isLoadingPhoto)
            }
        }
        .sheet(isPresented: $showingNewGame, onDismiss: {
            // Check if a new game was created and auto-start tracking
            if playerGames.count > gameCountBeforeNew {
                if let newestGameStats = activeGames.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        autoStartNewGameTracking(
                            for: newestGameStats,
                            startingPosition: pendingStartingPosition
                        )
                        pendingStartingPosition = nil
                    }
                }
            }
        }) {
            NewGameForPersonView(player: player) { _, startingPosition in
                pendingStartingPosition = startingPosition
            }
        }
        .sheet(isPresented: $showingAddToTeam) {
            AddPlayerToTeamView(player: player)
        }
        .fullScreenCover(item: $activeGameStats) { personGameStats in
            PlayerGameOverviewView(personGameStats: personGameStats)
        }
        .fullScreenCover(item: $newGameTrackingLaunch) { launch in
            GameTrackingView(
                game: launch.game,
                initialSelectedPersonStatsID: launch.selectedPersonStatsID,
                initialSelectedPosition: launch.startingPosition
            )
        }
        .sheet(item: $editingGame) { game in
            PlayerGameEditSheet(game: game)
        }
        .alert("Delete Game?", isPresented: deleteGameAlertBinding) {
            Button("Delete", role: .destructive) {
                deletePendingGame()
            }
            Button("Cancel", role: .cancel) {
                pendingGameDeletion = nil
            }
        } message: {
            if let pendingGameDeletion {
                Text("Delete this game from \(pendingGameDeletion.formattedDate)? This cannot be undone.")
            } else {
                Text("This cannot be undone.")
            }
        }
        .task(id: selectedPhoto) {
            guard isEditing, let selectedPhoto else { return }
            isLoadingPhoto = true
            defer { isLoadingPhoto = false }
            if let data = try? await selectedPhoto.loadTransferable(type: Data.self), !Task.isCancelled {
                draftPhotoData = PlayerPhotoStore.preparedData(from: data)
            }
        }
    }

    private func beginEditing() {
        draftFirstName = player.firstName
        draftLastName = player.lastName
        draftPhotoData = player.photoData
        draftPositions = Dictionary(uniqueKeysWithValues: player.activeTeamMemberships.map { ($0.id, $0.positionAssignments) })
        isEditing = true
    }

    private func savePlayerEdits() {
        let previous = (player.firstName, player.lastName, player.photoData)
        let memberships = player.activeTeamMemberships
        let previousPositions = memberships.map { ($0, $0.position, $0.positionAssignmentsJSON) }
        player.firstName = draftFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        player.lastName = draftLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        player.photoData = draftPhotoData
        for membership in memberships {
            if let draft = draftPositions[membership.id] { membership.positionAssignments = draft }
        }
        if persistence.save(modelContext, restoring: {
            (player.firstName, player.lastName, player.photoData) = previous
            for (membership, position, json) in previousPositions {
                membership.position = position
                membership.positionAssignmentsJSON = json
            }
        }) { isEditing = false }
    }

    private func startOrContinueGame() {
        if let preferredActiveGameStats {
            autoStartNewGameTracking(for: preferredActiveGameStats)
            return
        }

        gameCountBeforeNew = playerGames.count
        showingNewGame = true
    }

    private func autoStartNewGameTracking(
        for personGameStats: PersonGameStats,
        startingPosition: SoccerPosition? = nil
    ) {
        guard let game = personGameStats.game else { return }

        newGameTrackingLaunch = NewGameTrackingLaunch(
            game: game,
            selectedPersonStatsID: personGameStats.id,
            startingPosition: startingPosition
        )
    }

    private var deleteGameAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingGameDeletion != nil },
            set: { newValue in
                if !newValue {
                    pendingGameDeletion = nil
                }
            }
        )
    }

    private func deletePendingGame() {
        guard let game = pendingGameDeletion else { return }
        pendingGameDeletion = nil

        modelContext.delete(game)
        persistence.save(modelContext)
    }

    private func removeMemberships(at offsets: IndexSet) {
        let memberships = player.activeTeamMemberships
        let snapshots = offsets.map { (memberships[$0], memberships[$0].isActive) }
        for (membership, _) in snapshots { membership.isActive = false }
        persistence.save(modelContext, restoring: {
            for (membership, wasActive) in snapshots { membership.isActive = wasActive }
        })
    }

}

// MARK: - Person Game Row

struct PersonGameRow: View {
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
                            .accessibilityLabel("Completed")
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
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(game.listSummaryValue)")
                    .font(.title2.bold())
                    .foregroundStyle(.accent)

                Text(game.listSummaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct PlayerGameEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var persistence = PersistenceController()

    @Bindable var game: Game

    @State private var draftOpponent = ""
    @State private var draftLocation = ""
    @State private var draftDate = Date()
    @State private var draftNotes = ""
    @State private var draftIsCompleted = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Info") {
                    TextField("Opponent", text: $draftOpponent)
                    DatePicker("Date & Time", selection: $draftDate)
                    TextField("Location", text: $draftLocation)
                    Toggle("Completed", isOn: $draftIsCompleted)
                }

                Section("Notes") {
                    TextEditor(text: $draftNotes)
                        .frame(minHeight: 120)
                }
            }
            .persistenceAlert(persistence)
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
            .onAppear {
                draftOpponent = game.opponent
                draftLocation = game.location
                draftDate = game.gameDate
                draftNotes = game.notes
                draftIsCompleted = game.isCompleted
            }
        }
    }

    private func save() {
        if persistence.save(modelContext, operation: {
            try game.updateDetails(
                opponent: draftOpponent, location: draftLocation, date: draftDate,
                notes: draftNotes, isCompleted: draftIsCompleted, in: modelContext
            )
        }) { dismiss() }
    }

}

struct CareerHighCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(value)")
                .font(.title2.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PlusMinusCard: View {
    let value: String
    let label: String
    let plusMinus: Int

    private var color: Color {
        if plusMinus > 0 { return .green }
        if plusMinus < 0 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: plusMinus >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
