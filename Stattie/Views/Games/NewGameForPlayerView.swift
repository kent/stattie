import SwiftUI
import SwiftData
import UIKit

/// Simplified new game view for creating a game for a specific player
struct NewGameForPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Person
    var onGameCreated: ((PersonGameStats, SoccerPosition?) -> Void)? = nil

    @Query private var users: [User]
    @Query(sort: \Sport.name) private var sports: [Sport]

    @State private var opponent = ""
    @State private var location = ""
    @State private var gameDate = Date()
    @State private var selectedMembershipID: UUID?
    @State private var selectedSportID: UUID?
    @State private var selectedPositionID: String?
    @State private var didApplyDefaultMembership = false
    @State private var saveError: String?

    private var currentUser: User? { users.resolvedCurrentUser }
    private var selectedSport: Sport? {
        if let teamSport = selectedTeam?.sport { return teamSport }
        guard let selectedSportID else { return sports.first }
        return sports.first { $0.id == selectedSportID }
    }

    private var activeMemberships: [TeamMembership] {
        (player.teamMemberships ?? [])
            .filter {
                $0.isActive &&
                $0.team?.isActive == true &&
                $0.team?.isOwned(by: currentUser) == true
            }
            .sorted { ($0.team?.name ?? "") < ($1.team?.name ?? "") }
    }

    private var selectedMembership: TeamMembership? {
        guard let selectedMembershipID else { return nil }
        return activeMemberships.first { $0.id == selectedMembershipID }
    }

    private var selectedTeam: Team? {
        selectedMembership?.team
    }

    private var hasActiveTeamMembership: Bool {
        !activeMemberships.isEmpty
    }

    private var availablePositionAssignments: [PositionAssignment] {
        guard let selectedSport else { return [] }
        let source = selectedMembership.flatMap { membership in
            membership.positionAssignments.isEmpty ? nil : membership.positionAssignments
        } ?? player.positionAssignments
        let supportedSport = SoccerPosition.supportedSport(for: selectedSport.name)

        return source.assignments.filter { $0.position.supportedSport == supportedSport }
    }

    private var requiresPositionSelection: Bool {
        availablePositionAssignments.count > 1
    }

    private var hasValidPositionSelection: Bool {
        guard requiresPositionSelection else { return true }
        guard let selectedPositionID else { return false }
        return availablePositionAssignments.contains { $0.position.rawValue == selectedPositionID }
    }

    private var selectedStartingPosition: SoccerPosition? {
        if requiresPositionSelection {
            guard let selectedPositionID else { return nil }
            return availablePositionAssignments.first {
                $0.position.rawValue == selectedPositionID
            }?.position
        }
        return availablePositionAssignments.first?.position
    }

    private var displayJerseyNumber: Int? {
        if let teamJersey = selectedMembership?.jerseyNumber, teamJersey > 0 {
            return teamJersey
        }
        return player.jerseyNumber > 0 ? player.jerseyNumber : nil
    }

    private var displayPositionText: String? {
        let teamPosition = selectedMembership?.positionDisplayText ?? ""
        if !teamPosition.isEmpty && teamPosition != "No position" && teamPosition != "-" {
            return teamPosition
        }
        return player.position.isEmpty ? nil : player.position
    }

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
                                if let jersey = displayJerseyNumber {
                                    Text("#\(jersey)")
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
                            Text(player.fullName)
                                .font(.headline)
                            if let positionText = displayPositionText {
                                Text(positionText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Person")
                }

                if sports.count > 1 && selectedTeam == nil {
                    Section("Sport") {
                        Picker("Sport", selection: $selectedSportID) {
                            ForEach(sports) { sport in
                                Label(sport.name, systemImage: sport.iconName)
                                    .tag(sport.id as UUID?)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if hasActiveTeamMembership {
                    Section {
                        Picker("Team", selection: $selectedMembershipID) {
                            Text("No team")
                                .tag(nil as UUID?)
                            ForEach(activeMemberships) { membership in
                                if let team = membership.team {
                                    Text(teamDisplayName(for: team))
                                        .tag(membership.id as UUID?)
                                }
                            }
                        }
                    } header: {
                        Text("Team (Optional)")
                    } footer: {
                        Text("Team information is optional and does not add other players to the game.")
                    }
                }

                if requiresPositionSelection {
                    Section {
                        Picker("Position", selection: $selectedPositionID) {
                            Text("Choose a position")
                                .tag(nil as String?)
                            ForEach(availablePositionAssignments) { assignment in
                                Text(assignment.position.displayName)
                                    .tag(assignment.position.rawValue as String?)
                            }
                        }
                    } header: {
                        Text("Position")
                    } footer: {
                        Text("Choose the position this player will start the game in.")
                    }
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
                    .disabled(selectedSport == nil || !hasValidPositionSelection)
                }
            }
            .onAppear {
                if selectedSportID == nil {
                    selectedSportID = sports.first?.id
                }
                if !didApplyDefaultMembership {
                    didApplyDefaultMembership = true
                    if selectedMembershipID == nil {
                        selectedMembershipID = player.preferredMembership(from: activeMemberships)?.id
                    }
                }
            }
            .onChange(of: selectedSportID) { _, _ in
                selectedPositionID = nil
            }
            .onChange(of: selectedMembershipID) { _, _ in
                selectedPositionID = nil
            }
            .alert("Couldn’t Start Game", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func createGame() {
        guard let sportToUse = selectedSport,
              hasValidPositionSelection,
              let currentUser,
              player.isActive,
              player.isOwned(by: currentUser) else {
            saveError = "This player is not available for a new game."
            return
        }

        let game = Game(
            gameDate: gameDate,
            opponent: opponent.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            notes: "",
            isCompleted: false,
            sport: sportToUse,
            trackedBy: currentUser
        )

        if let selectedTeam {
            game.team = selectedTeam
        }
        modelContext.insert(game)

        // Create person stats for this game
        let personStats = PersonGameStats(person: player, game: game)
        modelContext.insert(personStats)

        game.personStats = [personStats]

        do {
            try modelContext.save()
            onGameCreated?(personStats, selectedStartingPosition)
            dismiss()
        } catch {
            modelContext.delete(personStats)
            modelContext.delete(game)
            saveError = error.localizedDescription
        }
    }

    private func teamDisplayName(for team: Team) -> String {
        if let sportName = team.sport?.name, !sportName.isEmpty {
            return "\(team.name) (\(sportName))"
        }
        return team.name
    }
}

#Preview {
    NewGameForPersonView(player: Person(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
        .modelContainer(for: [Game.self, Person.self, Team.self, TeamMembership.self, User.self, Sport.self], inMemory: true)
}
