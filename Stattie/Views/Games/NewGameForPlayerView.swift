import SwiftUI
import SwiftData
import UIKit

/// Simplified new game view for creating a game for a specific player
struct NewGameForPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Person

    @Query private var users: [User]
    @Query(filter: #Predicate<Sport> { $0.name == "Basketball" }) private var sports: [Sport]

    @State private var opponent = ""
    @State private var location = ""
    @State private var gameDate = Date()
    @State private var selectedMembershipID: UUID?

    private var currentUser: User? { users.first }
    private var basketball: Sport? { sports.first }

    private var activeMemberships: [TeamMembership] {
        (player.teamMemberships ?? [])
            .filter { $0.isActive && $0.team?.isActive == true }
            .sorted { ($0.team?.name ?? "") < ($1.team?.name ?? "") }
    }

    private var selectedMembership: TeamMembership? {
        guard let selectedMembershipID else { return activeMemberships.first }
        return activeMemberships.first { $0.id == selectedMembershipID }
    }

    private var selectedTeam: Team? {
        selectedMembership?.team
    }

    private var hasActiveTeamMembership: Bool {
        !activeMemberships.isEmpty
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

                if hasActiveTeamMembership {
                    Section("Team") {
                        ForEach(activeMemberships) { membership in
                            if let team = membership.team {
                                Button {
                                    selectedMembershipID = membership.id
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: team.colorHex))
                                                .frame(width: 34, height: 34)

                                            Image(systemName: team.iconName.isEmpty ? "sportscourt" : team.iconName)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(team.name)
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 6) {
                                                if let sportName = team.sport?.name {
                                                    Text(sportName)
                                                }
                                                if let jersey = membership.jerseyNumber, jersey > 0 {
                                                    Text("• #\(jersey)")
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if selectedMembership?.id == membership.id {
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
                    }
                }

                Section("Game Details") {
                    TextField("Opponent (optional)", text: $opponent)
                    TextField("Location (optional)", text: $location)
                    DatePicker("Date & Time", selection: $gameDate)
                }

                if !hasActiveTeamMembership {
                    Section {
                        Label("Add this player to a team before creating a game.", systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                    .disabled(selectedTeam == nil)
                }
            }
            .onAppear {
                if selectedMembershipID == nil {
                    selectedMembershipID = activeMemberships.first?.id
                }
            }
            .onChange(of: activeMemberships.map(\.id)) { _, membershipIDs in
                guard let selectedMembershipID else {
                    self.selectedMembershipID = membershipIDs.first
                    return
                }
                if !membershipIDs.contains(selectedMembershipID) {
                    self.selectedMembershipID = membershipIDs.first
                }
            }
        }
    }

    private func createGame() {
        guard let selectedTeam else { return }

        let sportToUse = selectedTeam.sport ?? basketball

        let game = Game(
            gameDate: gameDate,
            opponent: opponent.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            notes: "",
            isCompleted: false,
            sport: sportToUse,
            trackedBy: currentUser
        )

        game.team = selectedTeam
        modelContext.insert(game)

        // Create person stats for this game
        let personStats = PersonGameStats(person: player, game: game)
        modelContext.insert(personStats)

        if game.personStats == nil {
            game.personStats = []
        }
        game.personStats?.append(personStats)

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NewGameForPersonView(player: Person(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
        .modelContainer(for: [Game.self, Person.self, Team.self, TeamMembership.self, User.self, Sport.self], inMemory: true)
}
