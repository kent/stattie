import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Person

    @State private var isEditing = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingNewGame = false
    @State private var activeGameStats: PersonGameStats?
    @State private var newGameTrackingLaunch: NewGameTrackingLaunch?
    @State private var gameCountBeforeNew = 0
    @State private var pendingStartingPosition: SoccerPosition?
    @State private var editingGame: Game?
    @State private var pendingGameDeletion: Game?

    private struct NewGameTrackingLaunch: Identifiable {
        let id = UUID()
        let game: Game
        let selectedPersonStatsID: UUID
        let startingPosition: SoccerPosition?
    }

    // Get player's games sorted by date
    private var playerGames: [PersonGameStats] {
        (player.gameStats ?? [])
            .sorted { ($0.game?.gameDate ?? .distantPast) > ($1.game?.gameDate ?? .distantPast) }
    }

    private var activeGames: [PersonGameStats] {
        playerGames.filter { $0.game?.isCompleted == false }
    }

    private var preferredActiveGameStats: PersonGameStats? {
        activeGames.first
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
                    .accessibilityLabel(player.photoData == nil ? "Add player photo" : "Change player photo")
                    .accessibilityHint(isEditing ? "Opens the photo library" : "Enable editing to change the photo")
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
            }

            // Actions
            if !isEditing {
                Section {
                    Button {
                        startOrContinueGame()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                preferredActiveGameStats == nil ? "Start Game" : "Continue Game",
                                systemImage: preferredActiveGameStats == nil ? "play.circle.fill" : "arrow.right.circle.fill"
                            )
                            .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .listRowBackground(Color.accentColor)
                    .foregroundStyle(Color.white)
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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 16)], spacing: 16) {
                                CareerHighCard(value: player.careerHighPoints, label: "Points", icon: "flame.fill", color: .orange)
                                CareerHighCard(value: player.careerHighRebounds, label: "Rebounds", icon: "arrow.up.arrow.down", color: .green)
                                CareerHighCard(value: player.careerHighAssists, label: "Assists", icon: "arrow.triangle.branch", color: .blue)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        // Plus/Minus Section (if any games have shift data)
                        if player.careerPlusMinus != 0 || player.averagePlusMinus != 0 {
                            Section("Plus/Minus") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
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
        .navigationTitle(player.fullName)
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
        .sheet(isPresented: $showingNewGame, onDismiss: {
            // Check if a new game was created and auto-start tracking
            if playerGames.count > gameCountBeforeNew {
                if let newestGameStats = activeGames.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        autoStartNewGameTracking(
                            for: newestGameStats,
                            startingPosition: pendingStartingPosition
                        )
                        pendingStartingPosition = nil
                    }
                }
            }
        }) {
            NewGameForPersonView(player: player) { _, startingPosition in
                pendingStartingPosition = startingPosition
            }
        }
        .fullScreenCover(item: $activeGameStats) { personGameStats in
            PlayerGameOverviewView(personGameStats: personGameStats)
        }
        .fullScreenCover(item: $newGameTrackingLaunch) { launch in
            GameTrackingView(
                game: launch.game,
                initialSelectedPersonStatsID: launch.selectedPersonStatsID,
                initialSelectedPosition: launch.startingPosition
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
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    player.photoData = data
                    try? modelContext.save()
                }
            }
        }
    }

    private func startOrContinueGame() {
        if let preferredActiveGameStats {
            autoStartNewGameTracking(for: preferredActiveGameStats)
            return
        }

        gameCountBeforeNew = playerGames.count
        showingNewGame = true
    }

    private func autoStartNewGameTracking(
        for personGameStats: PersonGameStats,
        startingPosition: SoccerPosition? = nil
    ) {
        guard let game = personGameStats.game else { return }

        newGameTrackingLaunch = NewGameTrackingLaunch(
            game: game,
            selectedPersonStatsID: personGameStats.id,
            startingPosition: startingPosition
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
                            .accessibilityLabel("Completed")
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
        personGameStats.person?.fullName ?? "Player"
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
            OverviewMetric(id: "turnovers", title: "Turnovers", value: "\(personGameStats.aggregatedCount(forName: "TO"))"),
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
        showingTracking = true
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
