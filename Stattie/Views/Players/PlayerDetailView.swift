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
    @State private var activeGame: Game?
    @State private var gameCountBeforeNew = 0
    @State private var showingAddToTeam = false

    @Query(sort: \Team.name) private var allTeams: [Team]

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
                } else {
                    LabeledContent("Name", value: player.fullName)
                    LabeledContent("Jersey", value: "#\(player.jerseyNumber)")
                }
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
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
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
                                    activeGame = game
                                } label: {
                                    PersonGameRow(game: game)
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
                                    PersonGameRow(game: game)
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
            NewGameForPersonView(player: player)
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
            participantCount = await CloudKitShareManager.shared.getParticipantCount(for: player)
        }
    }

    private func startNewGame() {
        gameCountBeforeNew = playerGames.count
        showingNewGame = true
    }

    // MARK: - Teams Section

    private var playerTeams: [TeamMembership] {
        (player.teamMemberships ?? []).filter { $0.isActive }
    }

    private var availableTeams: [Team] {
        let currentTeamIDs = Set(playerTeams.compactMap { $0.team?.id })
        return allTeams.filter { $0.isActive && !currentTeamIDs.contains($0.id) }
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
            .disabled(availableTeams.isEmpty && !allTeams.isEmpty)
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
        .sheet(isPresented: $showingAddToTeam) {
            AddPersonToTeamView(person: player, availableTeams: availableTeams)
        }
    }
}

// MARK: - Person Team Row

struct PersonTeamRow: View {
    let team: Team
    let membership: TeamMembership

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
                    if let sport = team.sport {
                        Text(sport.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !membership.positionShortText.isEmpty && membership.positionShortText != "-" {
                        Text("•")
                            .foregroundStyle(.secondary)
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
    let availableTeams: [Team]

    @State private var selectedTeam: Team?
    @State private var positionAssignments: PositionAssignments = PositionAssignments()
    @State private var jerseyNumber: Int?

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
                                Text("#\(person.jerseyNumber)")
                                    .font(.headline)
                                    .foregroundStyle(.accent)
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
                        Text("No teams available. Create a team first.")
                            .foregroundStyle(.secondary)
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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if selectedTeam != nil {
                    Section("Jersey Number") {
                        HStack {
                            Text("Number")
                            Spacer()
                            TextField("", value: $jerseyNumber, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }

                    Section("Position on This Team") {
                        PositionPickerView(assignments: $positionAssignments)
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
                jerseyNumber = person.jerseyNumber
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

#Preview {
    NavigationStack {
        PersonDetailView(player: Person(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: Person.self, inMemory: true)
}
