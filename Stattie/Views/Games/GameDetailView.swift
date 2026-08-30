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

    private var isBasketball: Bool {
        game.sport?.name == "Basketball"
    }

    private struct GameStatLine: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    private var primaryScoreValue: Int {
        game.listSummaryValue
    }

    private var primaryScoreLabel: String {
        if isSoccer { return "Goals" }
        if isBasketball { return "Total Points" }
        if let profile = SportCatalog.profile(named: game.sport?.name) {
            return profile.primaryScoreLabel
        }
        return "Total"
    }

    private var gameStatLines: [GameStatLine] {
        var lines: [GameStatLine] = []

        if isSoccer {
            let shotsMade = game.totalMade(forName: "SOT")
            let shotsAttempts = shotsMade + game.totalMissed(forName: "SOT")
            if shotsAttempts > 0 {
                lines.append(GameStatLine(id: "SOT", title: "Shots On Target", value: "\(shotsMade)/\(shotsAttempts)"))
            }

            let countStats: [(String, String)] = [
                ("GOL", "Goals"),
                ("AST", "Assists"),
                ("SAV", "Saves"),
                ("TKL", "Tackles"),
                ("INT", "Interceptions"),
                ("PAS", "Passes"),
                ("CRN", "Corners"),
                ("FLS", "Fouls"),
                ("YC", "Yellow Cards"),
                ("RC", "Red Cards"),
            ]

            for (code, title) in countStats {
                let value = game.totalCount(forName: code)
                if value > 0 {
                    lines.append(GameStatLine(id: code, title: title, value: "\(value)"))
                }
            }
        } else if isBasketball {
            let shootingStats: [(String, String)] = [
                ("2PT", "2-Pointers"),
                ("3PT", "3-Pointers"),
                ("FT", "Free Throws"),
            ]

            for (code, title) in shootingStats {
                let made = game.totalMade(forName: code)
                let attempts = made + game.totalMissed(forName: code)
                if attempts > 0 {
                    lines.append(GameStatLine(id: code, title: title, value: "\(made)/\(attempts)"))
                }
            }

            let countStats: [(String, String)] = [
                ("DREB", "Defensive Rebounds"),
                ("OREB", "Offensive Rebounds"),
                ("AST", "Assists"),
                ("STL", "Steals"),
                ("PF", "Fouls"),
                ("TO", "Turnovers"),
                ("MD", "Missed Drive"),
                ("SD", "Successful Drive"),
                ("BPO", "Bad Offense"),
                ("BPD", "Bad Defense"),
                ("GPO", "Great Offense"),
                ("GPD", "Great Defense"),
            ]

            for (code, title) in countStats {
                let value = game.totalCount(forName: code)
                if value > 0 {
                    lines.append(GameStatLine(id: code, title: title, value: "\(value)"))
                }
            }
        } else {
            for definition in game.sport?.sortedStatDefinitions ?? [] {
                if definition.hasMadeAndMissed {
                    let made = game.totalMade(forName: definition.shortName)
                    let attempts = made + game.totalMissed(forName: definition.shortName)
                    if attempts > 0 {
                        lines.append(GameStatLine(
                            id: definition.shortName,
                            title: definition.name,
                            value: "\(made)/\(attempts)"
                        ))
                    }
                } else {
                    let value = game.totalCount(forName: definition.shortName)
                    if value > 0 {
                        lines.append(GameStatLine(
                            id: definition.shortName,
                            title: definition.name,
                            value: "\(value)"
                        ))
                    }
                }
            }
        }

        return lines
    }

    var body: some View {
        List {
            // Score header
            Section {
                VStack(spacing: 12) {
                    Text("\(primaryScoreValue)")
                        .scaledFont(size: 64, weight: .bold, relativeTo: .largeTitle)
                        .foregroundStyle(.accent)

                    Text(primaryScoreLabel)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Quick stats row
                    if isSoccer {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 16)], spacing: 12) {
                            QuickStatPill(value: game.totalCount(forName: "AST"), label: "AST")
                            QuickStatPill(value: game.totalCount(forName: "SAV"), label: "SAV")
                            QuickStatPill(value: game.totalMade(forName: "SOT"), label: "SOT")
                        }
                        .padding(.top, 8)
                    } else if isBasketball {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 16)], spacing: 12) {
                            QuickStatPill(value: game.totalCount(forName: "DREB") + game.totalCount(forName: "OREB"), label: "REB")
                            QuickStatPill(value: game.totalCount(forName: "AST"), label: "AST")
                            QuickStatPill(value: game.totalCount(forName: "STL"), label: "STL")
                            QuickStatPill(value: game.totalCount(forName: "TO"), label: "TO")
                        }
                        .padding(.top, 8)
                    } else if let profile = SportCatalog.profile(named: game.sport?.name) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 16)], spacing: 12) {
                            ForEach(profile.highlightShortNames, id: \.self) { shortName in
                                if let spec = profile.spec(shortName: shortName) {
                                    if spec.hasMadeAndMissed {
                                        QuickStatPill(value: game.totalMade(forName: shortName), label: shortName)
                                    } else {
                                        QuickStatPill(value: game.totalCount(forName: shortName), label: shortName)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }

            Section("Game Stats") {
                if gameStatLines.isEmpty {
                    Text("No stats recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(gameStatLines) { line in
                        LabeledContent(line.title, value: line.value)
                    }
                }
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
                    .accessibilityLabel("Game actions")
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 16)], alignment: .leading, spacing: 12) {
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

    private var accessibleLabel: String {
        switch label {
        case "REB": return "Rebounds"
        case "AST": return "Assists"
        case "STL": return "Steals"
        case "TO": return "Turnovers"
        case "SAV": return "Saves"
        case "SOT": return "Shots on target"
        default: return label
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 50)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibleLabel): \(value)")
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: Game(opponent: "Lakers", location: "Home Gym"))
    }
    .modelContainer(for: Game.self, inMemory: true)
}
