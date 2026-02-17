import SwiftUI
import SwiftData

struct TeamDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var team: Team

    @Query private var allPlayers: [Person]
    @State private var isEditing = false
    @State private var showingAddPlayer = false
    @State private var showingNewGame = false
    @State private var selectedMembership: TeamMembership?

    private var activeMembers: [Person] {
        team.members.filter { $0.isActive }
    }

    private var availablePlayers: [Person] {
        let teamMemberIDs = Set(team.members.map { $0.id })
        return allPlayers.filter { $0.isActive && !teamMemberIDs.contains($0.id) }
    }

    private var teamGames: [Game] {
        (team.games ?? [])
            .sorted { $0.gameDate > $1.gameDate }
    }

    var body: some View {
        List {
            // Team Header
            Section {
                HStack(spacing: 16) {
                    // Team icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: team.colorHex))
                            .frame(width: 80, height: 80)

                        Image(systemName: team.iconName.isEmpty ? "sportscourt" : team.iconName)
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if isEditing {
                            TextField("Team Name", text: $team.name)
                                .font(.title2.bold())
                        } else {
                            Text(team.name)
                                .font(.title2.bold())
                        }

                        if let sport = team.sport {
                            HStack {
                                Image(systemName: sport.iconName)
                                Text(sport.name)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 16) {
                            Label("\(activeMembers.count)", systemImage: "person.fill")
                            Label("\(teamGames.count)", systemImage: "sportscourt")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // Quick Actions
            if !isEditing {
                Section {
                    Button {
                        showingNewGame = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Game", systemImage: "play.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(.white)
                }
            }

            // Roster Section
            Section {
                ForEach(activeMembers) { person in
                    if let membership = team.memberships?.first(where: { $0.person?.id == person.id }) {
                        TeamMemberRow(membership: membership, person: person) {
                            selectedMembership = membership
                        }
                    }
                }
                .onDelete(perform: removeMember)

                if !isEditing {
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Label("Add Player", systemImage: "plus.circle")
                    }
                }
            } header: {
                Text("Roster (\(activeMembers.count))")
            }

            // Recent Games
            if !teamGames.isEmpty && !isEditing {
                Section("Recent Games") {
                    ForEach(teamGames.prefix(5)) { game in
                        NavigationLink(value: game) {
                            TeamGameRow(game: game)
                        }
                    }

                    if teamGames.count > 5 {
                        NavigationLink {
                            // Full game list
                            GameListView()
                        } label: {
                            Text("View All Games")
                                .foregroundStyle(.accent)
                        }
                    }
                }
            }

            // Team Stats Summary
            if !teamGames.isEmpty && !isEditing {
                Section("Season Stats") {
                    let completedGames = teamGames.filter { $0.isCompleted }
                    LabeledContent("Games Played", value: "\(completedGames.count)")

                    let totalPoints = completedGames.reduce(0) { $0 + $1.totalPoints }
                    LabeledContent("Total Points", value: "\(totalPoints)")

                    if !completedGames.isEmpty {
                        let avgPoints = Double(totalPoints) / Double(completedGames.count)
                        LabeledContent("Avg Points/Game", value: String(format: "%.1f", avgPoints))
                    }
                }
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        try? modelContext.save()
                    }
                    isEditing.toggle()
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerToTeamView(team: team, availablePlayers: availablePlayers)
        }
        .sheet(item: $selectedMembership) { membership in
            EditMembershipView(membership: membership)
        }
        .sheet(isPresented: $showingNewGame) {
            NewTeamGameView(team: team)
        }
    }

    private func removeMember(at offsets: IndexSet) {
        for index in offsets {
            let person = activeMembers[index]
            if let membership = team.memberships?.first(where: { $0.person?.id == person.id }) {
                membership.isActive = false
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Team Member Row

struct TeamMemberRow: View {
    let membership: TeamMembership
    let person: Person
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Player avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    if let photoData = person.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        if let jerseyNumber = membership.jerseyNumber, jerseyNumber > 0 {
                            Text("#\(jerseyNumber)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.accent)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.subheadline)
                                .foregroundStyle(.accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text(membership.positionShortText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if membership.hasMultiplePositions {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
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
}

// MARK: - Team Game Row

struct TeamGameRow: View {
    let game: Game

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
                        .font(.headline)

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

            Text("\(game.totalPoints)")
                .font(.title3.bold())
                .foregroundStyle(.accent)
        }
    }
}

// MARK: - Add Player to Team View

struct AddPlayerToTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let team: Team
    let availablePlayers: [Person]

    @State private var selectedPlayers: Set<UUID> = []
    @State private var searchText = ""

    private var filteredPlayers: [Person] {
        if searchText.isEmpty {
            return availablePlayers
        }
        return availablePlayers.filter { player in
            player.firstName.localizedCaseInsensitiveContains(searchText) ||
            player.lastName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availablePlayers.isEmpty {
                    ContentUnavailableView {
                        Label("No Available Players", systemImage: "person.slash")
                    } description: {
                        Text("All your players are already on this team, or you haven't added any players yet.")
                    }
                } else {
                    List(filteredPlayers, selection: $selectedPlayers) { player in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                if player.jerseyNumber > 0 {
                                    Text("#\(player.jerseyNumber)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.accent)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(.accent)
                                }
                            }

                            VStack(alignment: .leading) {
                                Text(player.fullName)
                                    .font(.headline)

                                if !player.position.isEmpty {
                                    Text(player.positionShortText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                    .searchable(text: $searchText, prompt: "Search players")
                }
            }
            .navigationTitle("Add Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedPlayers.count))") {
                        addSelectedPlayers()
                    }
                    .disabled(selectedPlayers.isEmpty)
                }
            }
        }
    }

    private func addSelectedPlayers() {
        for playerID in selectedPlayers {
            if let player = availablePlayers.first(where: { $0.id == playerID }) {
                let membership = TeamMembership(
                    person: player,
                    team: team,
                    role: "player",
                    jerseyNumber: player.jerseyNumber > 0 ? player.jerseyNumber : nil,
                    position: player.position,
                    positionAssignments: player.positionAssignments
                )
                modelContext.insert(membership)

                if team.memberships == nil {
                    team.memberships = []
                }
                team.memberships?.append(membership)

                if player.teamMemberships == nil {
                    player.teamMemberships = []
                }
                player.teamMemberships?.append(membership)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Membership View

struct EditMembershipView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var membership: TeamMembership

    @State private var editingPositions: PositionAssignments = PositionAssignments()

    var body: some View {
        NavigationStack {
            Form {
                if let person = membership.person {
                    Section {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                if let photoData = person.photoData,
                                   let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } else {
                                    if let jerseyNumber = membership.jerseyNumber, jerseyNumber > 0 {
                                        Text("#\(jerseyNumber)")
                                            .font(.title2.bold())
                                            .foregroundStyle(.accent)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.title2)
                                            .foregroundStyle(.accent)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.fullName)
                                    .font(.headline)

                                if let team = membership.team {
                                    Text(team.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Jersey Number") {
                    HStack {
                        Text("Number")
                        Spacer()
                        TextField("", value: $membership.jerseyNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Role") {
                    Picker("Role", selection: Binding(
                        get: { membership.role },
                        set: { membership.role = $0 }
                    )) {
                        Text("Player").tag("player")
                        Text("Captain").tag("captain")
                        Text("Coach").tag("coach")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Position on This Team") {
                    PositionPickerView(
                        assignments: $editingPositions,
                        sportName: membership.team?.sport?.name
                    )
                }

                if editingPositions.assignments.count > 1 {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("When starting a shift, you'll be asked to confirm which position they're playing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Membership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        membership.positionAssignments = editingPositions
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                editingPositions = membership.positionAssignments
            }
        }
    }
}

// MARK: - New Team Game View (placeholder)

struct NewTeamGameView: View {
    @Environment(\.dismiss) private var dismiss
    let team: Team

    var body: some View {
        NavigationStack {
            Text("Create a new game for \(team.name)")
                .navigationTitle("New Game")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Person.self, Sport.self, Game.self, configurations: config)

    let team = Team(name: "Warriors", iconName: "basketball.fill", colorHex: "2563EB")
    container.mainContext.insert(team)

    return NavigationStack {
        TeamDetailView(team: team)
    }
    .modelContainer(container)
}
