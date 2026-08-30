import SwiftUI
import SwiftData

/// Lets the user add a player to one or more existing teams, or create a new team.
struct AddPlayerToTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Person
    var onFinished: (() -> Void)? = nil

    @Query private var users: [User]
    @Query(sort: \Team.name) private var allTeams: [Team]

    @State private var selectedTeamIDs: Set<UUID> = []
    @State private var showingCreateTeam = false
    @State private var saveError: String?

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    private var availableTeams: [Team] {
        allTeams
            .filter { team in
                team.isActive &&
                team.isOwned(by: currentUser) &&
                !player.isMember(of: team)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var canSave: Bool {
        !selectedTeamIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Player", value: player.fullName)
                }

                if availableTeams.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Teams Yet", systemImage: "person.3")
                        } description: {
                            Text("Create a team to add \(player.fullName) to the roster.")
                        }
                    }
                } else {
                    Section {
                        ForEach(availableTeams) { team in
                            Button {
                                toggleSelection(for: team)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedTeamIDs.contains(team.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedTeamIDs.contains(team.id) ? Color.accentColor : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(team.name)
                                            .foregroundStyle(.primary)
                                        Text(team.sportDisplayText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .accessibilityLabel("\(team.name), \(team.sportDisplayText)")
                            .accessibilityAddTraits(selectedTeamIDs.contains(team.id) ? .isSelected : [])
                        }
                    } header: {
                        Text("Select Teams")
                    } footer: {
                        Text("Players can belong to more than one team.")
                    }
                }

                Section {
                    Button {
                        showingCreateTeam = true
                    } label: {
                        Label("Create New Team", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Add to a Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSelectedTeams()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingCreateTeam) {
                CreateTeamView { createdTeam in
                    selectedTeamIDs.insert(createdTeam.id)
                }
            }
            .alert("Couldn’t Add to Team", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func toggleSelection(for team: Team) {
        if selectedTeamIDs.contains(team.id) {
            selectedTeamIDs.remove(team.id)
        } else {
            selectedTeamIDs.insert(team.id)
        }
    }

    private func addSelectedTeams() {
        guard let currentUser, player.isOwned(by: currentUser) else {
            saveError = "This player is not available."
            return
        }

        let teamsToAdd = allTeams.filter {
            selectedTeamIDs.contains($0.id) &&
            $0.isActive &&
            $0.isOwned(by: currentUser)
        }
        guard !teamsToAdd.isEmpty else {
            saveError = "Select at least one team."
            return
        }

        for team in teamsToAdd {
            if let existingMembership = (player.teamMemberships ?? []).first(where: { $0.team?.id == team.id }) {
                existingMembership.isActive = true
                existingMembership.role = "player"
                if existingMembership.jerseyNumber == nil, player.jerseyNumber > 0 {
                    existingMembership.jerseyNumber = player.jerseyNumber
                }
                continue
            }

            let membership = TeamMembership(
                person: player,
                team: team,
                role: "player",
                jerseyNumber: player.jerseyNumber > 0 ? player.jerseyNumber : nil,
                position: player.position,
                positionAssignments: player.positionAssignments.isEmpty ? nil : player.positionAssignments,
                isActive: true
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

        do {
            try modelContext.save()
            onFinished?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    AddPlayerToTeamView(player: Person(firstName: "Maya", lastName: "Chen"))
        .modelContainer(for: [Person.self, Team.self, TeamMembership.self, Sport.self, User.self], inMemory: true)
}
