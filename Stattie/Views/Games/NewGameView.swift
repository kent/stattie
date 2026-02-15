import SwiftUI
import SwiftData

struct NewGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Person.jerseyNumber) private var players: [Person]
    @Query private var users: [User]
    @Query(sort: \Sport.name) private var allSports: [Sport]

    @State private var opponent = ""
    @State private var location = ""
    @State private var gameDate = Date()
    @State private var selectedPersons: Set<UUID> = []
    @State private var notes = ""
    @State private var selectedSport: Sport?

    // Quick add player fields
    @State private var quickAddName = ""
    @State private var quickAddNumber = ""
    @State private var showingQuickAdd = false

    private var currentUser: User? {
        users.first
    }

    private var availableSports: [Sport] {
        allSports
    }

    private var activePersons: [Person] {
        players.filter { $0.isActive }.sorted { $0.jerseyNumber < $1.jerseyNumber }
    }

    private var isValid: Bool {
        !selectedPersons.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Sport Selection
                if availableSports.count > 1 {
                    Section("Sport") {
                        Picker("Sport", selection: $selectedSport) {
                            ForEach(availableSports) { sport in
                                Label(sport.name, systemImage: sport.iconName)
                                    .tag(sport as Sport?)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Game Details") {
                    TextField("Opponent (optional)", text: $opponent)
                    TextField("Location (optional)", text: $location)
                    DatePicker("Date & Time", selection: $gameDate)
                }

                Section {
                    if activePersons.isEmpty && !showingQuickAdd {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No players yet")
                                .font(.headline)
                            Text("Add players to track their stats")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Add Players") {
                                showingQuickAdd = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    } else {
                        ForEach(activePersons) { player in
                            Button {
                                togglePerson(player)
                            } label: {
                                HStack {
                                    PersonSelectionRow(player: player)
                                    Spacer()
                                    if selectedPersons.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.accent)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("Select Players")
                        Spacer()
                        if !activePersons.isEmpty {
                            Button(selectedPersons.count == activePersons.count ? "Deselect All" : "Select All") {
                                if selectedPersons.count == activePersons.count {
                                    selectedPersons.removeAll()
                                } else {
                                    selectedPersons = Set(activePersons.map { $0.id })
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                // Quick Add Players Section
                Section {
                    if showingQuickAdd || !activePersons.isEmpty {
                        HStack(spacing: 12) {
                            TextField("#", text: $quickAddNumber)
                                .keyboardType(.numberPad)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)

                            TextField("Player name", text: $quickAddName)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                quickAddPerson()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(quickAddName.isEmpty && quickAddNumber.isEmpty)
                        }
                    }
                } header: {
                    if showingQuickAdd || !activePersons.isEmpty {
                        Text("Quick Add Player")
                    }
                } footer: {
                    if showingQuickAdd || !activePersons.isEmpty {
                        Text("Enter jersey # and/or name, then tap + to add")
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
                    .disabled(!isValid)
                }
            }
            .onAppear {
                // Set default sport if not already set
                if selectedSport == nil {
                    selectedSport = availableSports.first
                }
            }
        }
    }

    private func togglePerson(_ player: Person) {
        if selectedPersons.contains(player.id) {
            selectedPersons.remove(player.id)
        } else {
            selectedPersons.insert(player.id)
        }
    }

    private func quickAddPerson() {
        let name = quickAddName.trimmingCharacters(in: .whitespaces)
        let number = Int(quickAddNumber) ?? 0

        guard !name.isEmpty || number > 0 else { return }

        // Split name into first/last
        let nameParts = name.split(separator: " ", maxSplits: 1)
        let firstName = nameParts.first.map(String.init) ?? ""
        let lastName = nameParts.count > 1 ? String(nameParts[1]) : ""

        let player = Person(
            firstName: firstName,
            lastName: lastName,
            jerseyNumber: number,
            position: "",
            isActive: true,
            owner: currentUser
        )

        modelContext.insert(player)
        try? modelContext.save()

        // Auto-select the new player
        selectedPersons.insert(player.id)

        // Clear fields
        quickAddName = ""
        quickAddNumber = ""
    }

    private func createGame() {
        // Use selected sport or first available
        let sportToUse = selectedSport ?? availableSports.first

        let game = Game(
            gameDate: gameDate,
            opponent: opponent.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            isCompleted: false,
            sport: sportToUse,
            trackedBy: currentUser
        )

        modelContext.insert(game)

        for person in activePersons where selectedPersons.contains(person.id) {
            let personStats = PersonGameStats(person: person, game: game)
            modelContext.insert(personStats)

            if game.personStats == nil {
                game.personStats = []
            }
            game.personStats?.append(personStats)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct PersonSelectionRow: View {
    let player: Person

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Text("#\(player.jerseyNumber)")
                    .font(.caption.bold())
                    .foregroundStyle(.accent)
            }

            Text(player.fullName)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NewGameView()
        .modelContainer(for: [Game.self, Person.self, User.self, Sport.self], inMemory: true)
}
