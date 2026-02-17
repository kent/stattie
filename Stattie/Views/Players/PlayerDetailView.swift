import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Person

    @Query private var users: [User]
    @Query(filter: #Predicate<Sport> { $0.name == "Basketball" }) private var sports: [Sport]

    @State private var isEditing = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showShareInvite = false
    @State private var showManageSharing = false
    @State private var isShared = false
    @State private var isOwner = true
    @State private var participantCount = 0
    @State private var showingNewGame = false
    @State private var activeGameStats: PersonGameStats?
    @State private var newGameTrackingLaunch: NewGameTrackingLaunch?
    @State private var gameCountBeforeNew = 0
    @State private var showingAddToTeam = false
    @State private var editingGame: Game?
    @State private var pendingGameDeletion: Game?

    private struct NewGameTrackingLaunch: Identifiable {
        let id = UUID()
        let game: Game
        let selectedPersonStatsID: UUID
    }

    private var currentUser: User? { users.first }
    private var basketball: Sport? { sports.first }

    // Get player's games sorted by date
    private var playerGames: [PersonGameStats] {
        (player.gameStats ?? [])
            .sorted { ($0.game?.gameDate ?? .distantPast) > ($1.game?.gameDate ?? .distantPast) }
    }

    private var activeGames: [PersonGameStats] {
        playerGames.filter { $0.game?.isCompleted == false }
    }

    private var completedGames: [PersonGameStats] {
        playerGames.filter { $0.game?.isCompleted == true }
    }

    private var canRecordNewGame: Bool {
        !playerTeams.isEmpty
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
            Section {
                if isEditing {
                    TextField("First Name", text: $player.firstName)
                    TextField("Last Name", text: $player.lastName)
                } else {
                    LabeledContent("Name", value: player.fullName)
                }
            } header: {
                Text("Player Info")
            } footer: {
                Text("Jersey numbers are set per team.")
            }

            // Teams Section
            if !isEditing {
                teamsSection
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
                    .disabled(!canRecordNewGame)
                    .listRowBackground(canRecordNewGame ? Color.accentColor : Color(.secondarySystemFill))
                    .foregroundStyle(canRecordNewGame ? Color.white : Color.secondary)
                } footer: {
                    if !canRecordNewGame {
                        Text("Add this player to a team before recording a game.")
                    }
                }

                if !playerGames.isEmpty {
                    Section {
                        NavigationLink {
                            PersonStatsOverTimeView(player: player)
                        } label: {
                            Label("View Stats & Trends", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }

                    // Career Highs Section
                    if player.completedGamesCount > 0 {
                        Section("Career Highs") {
                            HStack(spacing: 16) {
                                CareerHighCard(value: player.careerHighPoints, label: "Points", icon: "flame.fill", color: .orange)
                                CareerHighCard(value: player.careerHighRebounds, label: "Rebounds", icon: "arrow.up.arrow.down", color: .green)
                                CareerHighCard(value: player.careerHighAssists, label: "Assists", icon: "arrow.triangle.branch", color: .blue)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        // Plus/Minus Section (if any games have shift data)
                        if player.careerPlusMinus != 0 || player.averagePlusMinus != 0 {
                            Section("Plus/Minus") {
                                HStack(spacing: 16) {
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

                // Share Section - visible and prominent
                Section {
                    Button {
                        if isShared {
                            showManageSharing = true
                        } else {
                            showShareInvite = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: isShared ? "person.2.fill" : "square.and.arrow.up")
                                .font(.title3)
                                .foregroundStyle(isShared ? .green : .accent)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                if isShared {
                                    Text("Shared with \(participantCount) \(participantCount == 1 ? "person" : "people")")
                                        .font(.body)
                                    Text("Tap to manage sharing")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Share with Family & Coaches")
                                        .font(.body)
                                    Text("Let others view and record games")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
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
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game)
        }
        .navigationDestination(for: Team.self) { team in
            TeamDetailView(team: team)
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
                                showShareInvite = true
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
        .sheet(isPresented: $showShareInvite) {
            ShareInviteView(player: player)
        }
        .sheet(isPresented: $showManageSharing) {
            ShareManagementView(player: player)
        }
        .sheet(isPresented: $showingAddToTeam) {
            AddPersonToTeamView(person: player)
        }
        .sheet(isPresented: $showingNewGame, onDismiss: {
            // Check if a new game was created and auto-start tracking
            if playerGames.count > gameCountBeforeNew {
                if let newestGameStats = activeGames.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        autoStartNewGameTracking(for: newestGameStats)
                    }
                }
            }
        }) {
            NewGameForPersonView(player: player)
        }
        .fullScreenCover(item: $activeGameStats) { personGameStats in
            PlayerGameOverviewView(personGameStats: personGameStats)
        }
        .fullScreenCover(item: $newGameTrackingLaunch) { launch in
            GameTrackingView(
                game: launch.game,
                initialSelectedPersonStatsID: launch.selectedPersonStatsID
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
            participantCount = await CloudKitShareManager.shared.getParticipantCount(for: player)
        }
    }

    private func startNewGame() {
        guard canRecordNewGame else { return }
        gameCountBeforeNew = playerGames.count
        showingNewGame = true
    }

    private func autoStartNewGameTracking(for personGameStats: PersonGameStats) {
        guard let game = personGameStats.game else { return }

        if personGameStats.currentShift == nil {
            let teamScore = personGameStats.completedShifts.last?.endingTeamScore ?? 0
            let opponentScore = personGameStats.completedShifts.last?.endingOpponentScore ?? 0
            let shift = personGameStats.startNewShift(teamScore: teamScore, opponentScore: opponentScore)
            modelContext.insert(shift)
            try? modelContext.save()
        }

        newGameTrackingLaunch = NewGameTrackingLaunch(
            game: game,
            selectedPersonStatsID: personGameStats.id
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
        try? modelContext.save()
    }

    // MARK: - Teams Section

    private var playerTeams: [TeamMembership] {
        (player.teamMemberships ?? []).filter { $0.isActive && $0.team?.isActive == true }
    }

    @ViewBuilder
    private var teamsSection: some View {
        Section {
            if playerTeams.isEmpty {
                HStack {
                    Image(systemName: "person.3")
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No team yet")
                            .foregroundStyle(.secondary)
                        Text("Add to a team to track position per team")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(playerTeams) { membership in
                    if let team = membership.team {
                        NavigationLink(value: team) {
                            PersonTeamRow(team: team, membership: membership)
                        }
                    }
                }
            }

            Button {
                showingAddToTeam = true
            } label: {
                Label("Add to Team", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Teams")
                Spacer()
                if playerTeams.count > 0 {
                    Text("\(playerTeams.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Person Team Row

struct PersonTeamRow: View {
    let team: Team
    let membership: TeamMembership

    private var jerseyText: String? {
        guard let jerseyNumber = membership.jerseyNumber, jerseyNumber > 0 else { return nil }
        return "#\(jerseyNumber)"
    }

    private var hasPositionText: Bool {
        !membership.positionShortText.isEmpty && membership.positionShortText != "-"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: team.colorHex))
                    .frame(width: 40, height: 40)

                Image(systemName: team.iconName.isEmpty ? "sportscourt" : team.iconName)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let jerseyText {
                        Text(jerseyText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let sport = team.sport {
                        if jerseyText != nil {
                            Text("•")
                                .foregroundStyle(.secondary)
                        }
                        Text(sport.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if hasPositionText {
                        if jerseyText != nil || team.sport != nil {
                            Text("•")
                                .foregroundStyle(.secondary)
                        }
                        Text(membership.positionShortText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if membership.hasMultiplePositions {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Add Person to Team View

struct AddPersonToTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let person: Person

    @Query(sort: \Team.name) private var allTeams: [Team]

    @State private var selectedTeam: Team?
    @State private var positionAssignments: PositionAssignments = PositionAssignments()
    @State private var jerseyNumber: Int?
    @State private var showingCreateTeam = false

    private var availableTeams: [Team] {
        let currentTeamIDs = Set(
            (person.teamMemberships ?? [])
                .filter { $0.isActive }
                .compactMap { $0.team?.id }
        )
        return allTeams.filter { $0.isActive && !currentTeamIDs.contains($0.id) }
    }

    private var hasAnyActiveTeams: Bool {
        allTeams.contains { $0.isActive }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 50, height: 50)

                            if let photoData = person.photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                if person.jerseyNumber > 0 {
                                    Text("#\(person.jerseyNumber)")
                                        .font(.headline)
                                        .foregroundStyle(.accent)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.headline)
                                        .foregroundStyle(.accent)
                                }
                            }
                        }

                        VStack(alignment: .leading) {
                            Text(person.fullName)
                                .font(.headline)
                            Text("Adding to team")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Select Team") {
                    if availableTeams.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if hasAnyActiveTeams {
                                Text("This player is already on all active teams.")
                            } else {
                                Text("No teams available yet.")
                            }
                            Text("Create a team to continue.")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    } else {
                        ForEach(availableTeams) { team in
                            Button {
                                selectedTeam = team
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: team.colorHex))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: team.iconName.isEmpty ? "sportscourt" : team.iconName)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(team.name)
                                            .foregroundStyle(.primary)

                                        if let sport = team.sport {
                                            Text(sport.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if selectedTeam?.id == team.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.accent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        showingCreateTeam = true
                    } label: {
                        Label("Create New Team", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.accent)
                }

                if selectedTeam != nil {
                    Section("Jersey Number") {
                        TextField("Enter jersey number", value: $jerseyNumber, format: .number)
                            .keyboardType(.numberPad)
                    }

                    Section("Position on This Team") {
                        PositionPickerView(
                            assignments: $positionAssignments,
                            sportName: selectedTeam?.sport?.name
                        )
                    }

                    if positionAssignments.assignments.count > 1 {
                        Section {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text("Multiple positions: You'll confirm position when starting a shift.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addToTeam()
                    }
                    .disabled(selectedTeam == nil)
                }
            }
            .onAppear {
                // Default to person's jersey number only (positions are team-specific)
                jerseyNumber = person.jerseyNumber > 0 ? person.jerseyNumber : nil
            }
            .onChange(of: availableTeams.map(\.id)) { _, teamIDs in
                guard let selectedTeam else { return }
                if !teamIDs.contains(selectedTeam.id) {
                    self.selectedTeam = nil
                }
            }
            .sheet(isPresented: $showingCreateTeam) {
                AddTeamView()
            }
        }
    }

    private func addToTeam() {
        guard let team = selectedTeam else { return }

        let membership = TeamMembership(
            person: person,
            team: team,
            role: "player",
            jerseyNumber: jerseyNumber,
            position: positionAssignments.displayText,
            positionAssignments: positionAssignments
        )

        modelContext.insert(membership)

        if team.memberships == nil {
            team.memberships = []
        }
        team.memberships?.append(membership)

        if person.teamMemberships == nil {
            person.teamMemberships = []
        }
        person.teamMemberships?.append(membership)

        try? modelContext.save()
        dismiss()
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
                Text("\(game.totalPoints)")
                    .font(.title2.bold())
                    .foregroundStyle(.accent)

                Text("points")
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
                        dismiss()
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
        game.opponent = draftOpponent.trimmingCharacters(in: .whitespacesAndNewlines)
        game.location = draftLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        game.gameDate = draftDate
        game.notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        game.isCompleted = draftIsCompleted
        try? modelContext.save()
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

struct PlayerGameOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var personGameStats: PersonGameStats

    @State private var showingTracking = false
    @State private var showingEndGameAlert = false
    @State private var pendingShiftDeletion: Shift?

    private struct OverviewMetric: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    private var game: Game? {
        personGameStats.game
    }

    private var playerName: String {
        personGameStats.person?.displayName ?? "Player"
    }

    private var isSoccer: Bool {
        game?.sport?.name == "Soccer"
    }

    private var hasActiveShift: Bool {
        personGameStats.currentShift != nil
    }

    private var completedShiftsNewestFirst: [Shift] {
        Array(personGameStats.completedShifts.reversed())
    }

    private var totalShiftCount: Int {
        (personGameStats.shifts ?? []).count
    }

    private var scoreSubtitle: String {
        if let activeShift = personGameStats.currentShift {
            return "Shift \(activeShift.shiftNumber) in progress • \(activeShift.startingTeamScore)-\(activeShift.startingOpponentScore) at start"
        }
        if let latest = personGameStats.completedShifts.last {
            let endingTeam = latest.endingTeamScore ?? latest.startingTeamScore
            let endingOpponent = latest.endingOpponentScore ?? latest.startingOpponentScore
            return "Last recorded score: \(endingTeam)-\(endingOpponent)"
        }
        return "No score captured yet"
    }

    private var totalPlusMinusColor: Color {
        if personGameStats.totalPlusMinus > 0 { return .green }
        if personGameStats.totalPlusMinus < 0 { return .red }
        return .secondary
    }

    private var snapshotMetrics: [OverviewMetric] {
        if isSoccer {
            let shotsMade = personGameStats.aggregatedMade(forName: "SOT")
            let shotsMissed = personGameStats.aggregatedMissed(forName: "SOT")
            let attempts = shotsMade + shotsMissed
            return [
                OverviewMetric(id: "goals", title: "Goals", value: "\(personGameStats.aggregatedCount(forName: "GOL"))"),
                OverviewMetric(id: "shots", title: "Shots", value: "\(shotsMade)/\(attempts)"),
                OverviewMetric(id: "assists", title: "Assists", value: "\(personGameStats.aggregatedCount(forName: "AST"))"),
                OverviewMetric(id: "saves", title: "Saves", value: "\(personGameStats.aggregatedCount(forName: "SAV"))"),
                OverviewMetric(id: "tackles", title: "Tackles", value: "\(personGameStats.aggregatedCount(forName: "TKL"))"),
                OverviewMetric(id: "interceptions", title: "Interceptions", value: "\(personGameStats.aggregatedCount(forName: "INT"))")
            ]
        }

        return [
            OverviewMetric(id: "points", title: "Points", value: "\(personGameStats.totalPoints)"),
            OverviewMetric(id: "rebounds", title: "Rebounds", value: "\(personGameStats.aggregatedCount(forName: "DREB") + personGameStats.aggregatedCount(forName: "OREB"))"),
            OverviewMetric(id: "assists", title: "Assists", value: "\(personGameStats.aggregatedCount(forName: "AST"))"),
            OverviewMetric(id: "steals", title: "Steals", value: "\(personGameStats.aggregatedCount(forName: "STL"))"),
            OverviewMetric(id: "fouls", title: "Fouls", value: "\(personGameStats.aggregatedCount(forName: "PF"))"),
            OverviewMetric(id: "missed_drive", title: "Missed Drive", value: "\(personGameStats.aggregatedCount(forName: "MD"))"),
            OverviewMetric(id: "successful_drive", title: "Successful Drive", value: "\(personGameStats.aggregatedCount(forName: "SD"))")
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                statusSection
                currentShiftSection
                shiftsSection
                totalsSection
                snapshotSection
            }
            .navigationTitle("Game Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, content: actionBar)
            .fullScreenCover(isPresented: $showingTracking, content: trackingDestination)
            .alert("Delete Shift?", isPresented: deleteShiftAlertBinding) {
                Button("Delete Shift", role: .destructive) {
                    deletePendingShift()
                }
                Button("Cancel", role: .cancel) {
                    pendingShiftDeletion = nil
                }
            } message: {
                if let pendingShiftDeletion {
                    Text("Shift \(pendingShiftDeletion.shiftNumber) and its stats will be removed.")
                } else {
                    Text("This shift and its stats will be removed.")
                }
            }
            .alert("End Game?", isPresented: $showingEndGameAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Game", role: .destructive) {
                    game?.isCompleted = true
                    try? modelContext.save()
                }
            } message: {
                Text("This will mark the game as completed.")
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill((game?.isCompleted ?? false) ? .gray : .green)
                        .frame(width: 10, height: 10)
                    Text((game?.isCompleted ?? false) ? "Ended" : "In Progress")
                        .font(.subheadline.weight(.semibold))
                }

                if let opponent = game?.opponent, !opponent.isEmpty {
                    Text("vs \(opponent)")
                        .font(.headline)
                } else {
                    Text("Game")
                        .font(.headline)
                }

                Text(game?.formattedDate ?? "--")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let teamName = game?.team?.name,
                   let sportName = game?.sport?.name {
                    Text("\(teamName) • \(sportName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(scoreSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var currentShiftSection: some View {
        if let activeShift = personGameStats.currentShift {
            Section("Current Shift") {
                ShiftSummaryRow(shift: activeShift)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingShiftDeletion = activeShift
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var shiftsSection: some View {
        Section("Shifts") {
            if completedShiftsNewestFirst.isEmpty && personGameStats.currentShift == nil {
                Text("No shifts yet. Start one to begin tracking stats.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(completedShiftsNewestFirst) { shift in
                    NavigationLink {
                        ShiftEditView(shift: shift, playerName: playerName)
                    } label: {
                        ShiftSummaryRow(shift: shift)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingShiftDeletion = shift
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var totalsSection: some View {
        Section("Totals") {
            LabeledContent("Shifts", value: "\(totalShiftCount)")
            LabeledContent("Time on court", value: personGameStats.formattedTotalShiftTime)
            LabeledContent("Points", value: "\(personGameStats.totalPoints)")

            HStack {
                Text("Plus/Minus")
                Spacer()
                Text(personGameStats.formattedTotalPlusMinus)
                    .fontWeight(.semibold)
                    .foregroundStyle(totalPlusMinusColor)
            }
        }
    }

    @ViewBuilder
    private var snapshotSection: some View {
        Section(isSoccer ? "Soccer Snapshot" : "Basketball Snapshot") {
            ForEach(snapshotMetrics) { metric in
                LabeledContent(metric.title, value: metric.value)
            }
        }
    }

    @ViewBuilder
    private func actionBar() -> some View {
        if !(game?.isCompleted ?? false) {
            VStack(spacing: 10) {
                Button {
                    openTracker()
                } label: {
                    Label(hasActiveShift ? "Continue Shift Tracking" : "Start New Shift", systemImage: hasActiveShift ? "waveform.path.ecg" : "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(role: .destructive) {
                    showingEndGameAlert = true
                } label: {
                    Text("End Game")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func trackingDestination() -> some View {
        if let game {
            GameTrackingView(game: game, initialSelectedPersonStatsID: personGameStats.id)
        } else {
            NavigationStack {
                ContentUnavailableView("Game Missing", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var deleteShiftAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingShiftDeletion != nil },
            set: { newValue in
                if !newValue {
                    pendingShiftDeletion = nil
                }
            }
        )
    }

    private func openTracker() {
        startShiftIfNeeded()
        showingTracking = true
    }

    private func startShiftIfNeeded() {
        guard personGameStats.currentShift == nil else { return }

        let lastCompleted = personGameStats.completedShifts.last
        let teamScore = lastCompleted?.endingTeamScore ?? 0
        let opponentScore = lastCompleted?.endingOpponentScore ?? 0
        let shift = personGameStats.startNewShift(teamScore: teamScore, opponentScore: opponentScore)
        modelContext.insert(shift)
        normalizeShiftNumbers()
        try? modelContext.save()
    }

    private func deletePendingShift() {
        guard let shift = pendingShiftDeletion else { return }
        pendingShiftDeletion = nil

        personGameStats.shifts?.removeAll { $0.id == shift.id }
        modelContext.delete(shift)
        normalizeShiftNumbers()
        try? modelContext.save()
    }

    private func normalizeShiftNumbers() {
        let orderedShifts = (personGameStats.shifts ?? [])
            .sorted { lhs, rhs in
                if lhs.startTime != rhs.startTime {
                    return lhs.startTime < rhs.startTime
                }
                return lhs.createdAt < rhs.createdAt
            }

        for (index, shift) in orderedShifts.enumerated() {
            shift.shiftNumber = index + 1
        }
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(player: Person(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: Person.self, inMemory: true)
}
