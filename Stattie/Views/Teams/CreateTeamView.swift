import SwiftUI
import SwiftData

/// Creates a team for a single sport.
struct CreateTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Team) -> Void)? = nil

    @Query private var users: [User]
    @Query(sort: \Sport.name) private var sports: [Sport]

    @State private var name = ""
    @State private var selectedSportID: UUID?
    @State private var saveError: String?

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedSport: Sport? {
        guard let selectedSportID else { return nil }
        return sports.first { $0.id == selectedSportID }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && selectedSport != nil
    }

    private var suggestedIconName: String {
        guard let selectedSport else { return "person.3.fill" }
        return selectedSport.iconName.isEmpty ? "person.3.fill" : selectedSport.iconName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Team Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Team")
                }

                Section {
                    Picker("Sport", selection: $selectedSportID) {
                        Text("Select a sport").tag(nil as UUID?)
                        ForEach(sports) { sport in
                            Label(sport.name, systemImage: sport.iconName.isEmpty ? "sportscourt" : sport.iconName)
                                .tag(sport.id as UUID?)
                        }
                    }
                } header: {
                    Text("Sport")
                } footer: {
                    Text("Each team belongs to one sport.")
                }
            }
            .navigationTitle("New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTeam()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if selectedSportID == nil {
                    selectedSportID = sports.first?.id
                }
            }
            .alert("Couldn’t Create Team", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func createTeam() {
        guard isValid, let selectedSport else { return }

        let team = Team(
            name: trimmedName,
            iconName: suggestedIconName,
            colorHex: "",
            isActive: true,
            sport: selectedSport,
            owner: currentUser
        )
        modelContext.insert(team)

        if selectedSport.teams == nil {
            selectedSport.teams = []
        }
        selectedSport.teams?.append(team)

        if let currentUser {
            if currentUser.teams == nil {
                currentUser.teams = []
            }
            currentUser.teams?.append(team)
        }

        do {
            try modelContext.save()
            onCreated?(team)
            dismiss()
        } catch {
            modelContext.delete(team)
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    CreateTeamView()
        .modelContainer(for: [Team.self, Sport.self, User.self], inMemory: true)
}
