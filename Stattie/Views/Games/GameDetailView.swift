import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var game: Game

    @State private var isEditing = false
    @State private var draftOpponent = ""
    @State private var draftLocation = ""
    @State private var draftDate = Date()
    @State private var draftNotes = ""
    @State private var draftIsCompleted = false

    @State private var showingSummary = false
    @State private var showingTracking = false
    @State private var showingDeleteConfirmation = false

    var sortedPersonStats: [PersonGameStats] {
        (game.personStats ?? []).sorted {
            ($0.person?.jerseyNumber ?? 0) < ($1.person?.jerseyNumber ?? 0)
        }
    }

    private var isSoccer: Bool {
        game.sport?.name == "Soccer"
    }

    var body: some View {
        List {
            // Score header
            Section {
                VStack(spacing: 12) {
                    Text("\(game.totalPoints)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.accent)

                    Text(isSoccer ? "Goals" : "Total Points")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Quick stats row
                    if !isSoccer {
                        HStack(spacing: 24) {
                            QuickStatPill(value: game.stat(named: "DREB")?.count ?? 0 + (game.stat(named: "OREB")?.count ?? 0), label: "REB")
                            QuickStatPill(value: game.stat(named: "AST")?.count ?? 0, label: "AST")
                            QuickStatPill(value: game.stat(named: "STL")?.count ?? 0, label: "STL")
                        }
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 24) {
                            QuickStatPill(value: game.stat(named: "AST")?.count ?? 0, label: "AST")
                            QuickStatPill(value: game.stat(named: "SAV")?.count ?? 0, label: "SAV")
                            QuickStatPill(value: game.stat(named: "SOT")?.made ?? 0, label: "SOT")
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }

            Section("Game Info") {
                if isEditing {
                    TextField("Opponent", text: $draftOpponent)
                    DatePicker("Date & Time", selection: $draftDate)
                    TextField("Location", text: $draftLocation)
                    Toggle("Completed", isOn: $draftIsCompleted)
                } else {
                    if !game.opponent.isEmpty {
                        LabeledContent("Opponent", value: game.opponent)
                    }
                    LabeledContent("Date", value: game.formattedDate)
                    if !game.location.isEmpty {
                        LabeledContent("Location", value: game.location)
                    }
                    LabeledContent("Status", value: game.isCompleted ? "Ended" : "In Progress")
                }
            }

            Section("Player Stats") {
                ForEach(sortedPersonStats) { pgs in
                    if let person = pgs.person {
                        PersonStatsRow(person: person, stats: pgs)
                    }
                }
            }

            if isEditing || !game.notes.isEmpty {
                Section("Notes") {
                    if isEditing {
                        TextEditor(text: $draftNotes)
                            .frame(minHeight: 120)
                    } else {
                        Text(game.notes)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isEditing {
                Section {
                    Button("Delete Game", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }

            if !isEditing {
                Section {
                    if game.isCompleted {
                        Button {
                            showingSummary = true
                        } label: {
                            Label("View & Share Summary", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            showingTracking = true
                        } label: {
                            Label("Continue Tracking", systemImage: "play.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game Details" : "vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        loadDraftFromGame()
                        isEditing = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyDraftToGame()
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            loadDraftFromGame()
                            isEditing = true
                        }
                        Button("Delete Game", systemImage: "trash", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSummary) {
            GameSummaryView(game: game)
        }
        .fullScreenCover(isPresented: $showingTracking) {
            GameTrackingView(game: game)
        }
        .alert("Delete Game?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the game and all tracked stats.")
        }
        .onAppear {
            loadDraftFromGame()
        }
    }

    private func loadDraftFromGame() {
        draftOpponent = game.opponent
        draftLocation = game.location
        draftDate = game.gameDate
        draftNotes = game.notes
        draftIsCompleted = game.isCompleted
    }

    private func applyDraftToGame() {
        game.opponent = draftOpponent.trimmingCharacters(in: .whitespaces)
        game.location = draftLocation.trimmingCharacters(in: .whitespaces)
        game.gameDate = draftDate
        game.notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        game.isCompleted = draftIsCompleted

        try? modelContext.save()
        isEditing = false
    }

    private func deleteGame() {
        modelContext.delete(game)
        try? modelContext.save()
        dismiss()
    }
}

struct PersonStatsRow: View {
    let person: Person
    let stats: PersonGameStats

    private var plusMinusColor: Color {
        let pm = stats.totalPlusMinus
        if pm > 0 { return .green }
        if pm < 0 { return .red }
        return .secondary
    }

    private var hasShifts: Bool {
        !stats.completedShifts.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(person.displayName)
                    .font(.headline)
                Spacer()

                if hasShifts {
                    // Show plus/minus if shifts were tracked
                    Text(stats.formattedTotalPlusMinus)
                        .font(.subheadline.bold())
                        .foregroundStyle(plusMinusColor)
                        .padding(.trailing, 8)
                }

                Text("\(stats.totalPoints) pts")
                    .font(.headline)
                    .foregroundStyle(.accent)
            }

            HStack(spacing: 16) {
                ForEach(stats.stats?.filter { $0.total > 0 } ?? [], id: \.id) { stat in
                    if let def = stat.definition {
                        VStack(spacing: 2) {
                            Text(stat.displayValue)
                                .font(.subheadline.bold())
                            Text(def.shortName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Show shift info if tracked
                if hasShifts {
                    VStack(spacing: 2) {
                        Text("\(stats.completedShifts.count)")
                            .font(.subheadline.bold())
                        Text("SHIFTS")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text(stats.formattedTotalShiftTime)
                            .font(.subheadline.bold())
                        Text("TIME")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickStatPill: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 50)
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: Game(opponent: "Lakers", location: "Home Gym"))
    }
    .modelContainer(for: Game.self, inMemory: true)
}
