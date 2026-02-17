import SwiftUI
import SwiftData
import UIKit

// MARK: - Undo Action

enum UndoActionType {
    case made(statName: String, points: Int)
    case missed(statName: String, points: Int)
    case count(statName: String)
}

struct UndoAction {
    let type: UndoActionType
    let timestamp: Date

    var description: String {
        switch type {
        case .made(let name, _): return "\(name) made"
        case .missed(let name, _): return "\(name) miss"
        case .count(let name): return name
        }
    }
}

struct GameTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    let initialSelectedPersonStatsID: UUID?
    @State private var showingEndGameAlert = false
    @State private var showingSummary = false
    @State private var showMilestoneAnimation = false
    @State private var milestoneText = ""
    @State private var previousDoubleDigits = 0

    // Game timer
    @State private var gameElapsedTime: TimeInterval = 0
    @State private var timerRunning = false
    @State private var gameStartTime: Date?

    // Undo support
    @State private var lastAction: UndoAction?
    @State private var showingUndoToast = false

    // Shift tracking flow
    @State private var showingEndShiftSheet = false
    @State private var showingShiftHistorySheet = false
    @State private var showingPostShiftOverviewSheet = false
    @State private var selectedShiftPersonStatsID: UUID?
    @State private var didBootstrapInitialShift = false
    @State private var shiftTeamScore: Int = 0
    @State private var shiftOpponentScore: Int = 0

    // Haptic feedback generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private var isSoccer: Bool {
        game.sport?.name == "Soccer"
    }

    private var shiftTrackablePersonStats: [PersonGameStats] {
        (game.personStats ?? [])
            .filter { $0.person != nil }
            .sorted { lhs, rhs in
                let leftJersey = lhs.person?.jerseyNumber ?? Int.max
                let rightJersey = rhs.person?.jerseyNumber ?? Int.max
                if leftJersey != rightJersey {
                    return leftJersey < rightJersey
                }
                let leftName = lhs.person?.fullName ?? ""
                let rightName = rhs.person?.fullName ?? ""
                return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
            }
    }

    private var selectedShiftPersonStats: PersonGameStats? {
        guard let selectedShiftPersonStatsID else { return shiftTrackablePersonStats.first }
        return shiftTrackablePersonStats.first { $0.id == selectedShiftPersonStatsID }
    }

    private var selectedShiftPlayerName: String {
        selectedShiftPersonStats?.person?.displayName ?? "Player"
    }

    private var activeShift: Shift? {
        selectedShiftPersonStats?.currentShift
    }

    private var hasShiftTracking: Bool {
        !shiftTrackablePersonStats.isEmpty
    }

    private var totalShiftCount: Int {
        (selectedShiftPersonStats?.shifts ?? []).count
    }

    private var latestCompletedShift: Shift? {
        selectedShiftPersonStats?.completedShifts.last
    }

    private var lastKnownShiftTeamScore: Int {
        selectedShiftPersonStats?.completedShifts.last?.endingTeamScore ?? 0
    }

    private var lastKnownShiftOpponentScore: Int {
        selectedShiftPersonStats?.completedShifts.last?.endingOpponentScore ?? 0
    }

    var totalPoints: Int {
        game.totalPoints
    }

    // Basketball stats
    var totalRebounds: Int {
        (game.stat(named: "DREB")?.count ?? 0) + (game.stat(named: "OREB")?.count ?? 0)
    }

    var totalAssists: Int {
        game.stat(named: "AST")?.count ?? 0
    }

    var totalSteals: Int {
        game.stat(named: "STL")?.count ?? 0
    }

    // Soccer stats
    var totalGoals: Int {
        game.stat(named: "GOL")?.count ?? 0
    }

    var totalSaves: Int {
        game.stat(named: "SAV")?.count ?? 0
    }

    private var doubleDigitCategories: Int {
        var count = 0
        if totalPoints >= 10 { count += 1 }
        if totalRebounds >= 10 { count += 1 }
        if totalAssists >= 10 { count += 1 }
        if totalSteals >= 10 { count += 1 }
        return count
    }

    var hasDoubleDouble: Bool {
        !isSoccer && doubleDigitCategories >= 2
    }

    var hasTripleDouble: Bool {
        !isSoccer && doubleDigitCategories >= 3
    }

    private var formattedTime: String {
        let minutes = Int(gameElapsedTime) / 60
        let seconds = Int(gameElapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init(game: Game, initialSelectedPersonStatsID: UUID? = nil) {
        self._game = Bindable(game)
        self.initialSelectedPersonStatsID = initialSelectedPersonStatsID
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Timer bar
                HStack {
                    // Timer display
                    Button {
                        toggleTimer()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(formattedTime)
                                .font(.system(.title2, design: .monospaced, weight: .semibold))
                        }
                        .foregroundStyle(timerRunning ? .green : .secondary)
                    }

                    Spacer()

                    // Undo button
                    if lastAction != nil {
                        Button {
                            performUndo()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                if hasShiftTracking {
                    shiftControls
                }

                if isSoccer {
                    soccerTrackingView
                } else {
                    basketballTrackingView
                }
            }
            .navigationTitle(game.opponent.isEmpty ? "Track Game" : "vs \(game.opponent)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("End Game") {
                        showingEndGameAlert = true
                    }
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if timerRunning {
                    gameElapsedTime += 1
                }
            }
            .alert("End Game?", isPresented: $showingEndGameAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Game", role: .destructive) {
                    game.isCompleted = true
                    try? modelContext.save()
                    showingSummary = true
                }
            } message: {
                Text("This will mark the game as completed.")
            }
            .sheet(isPresented: $showingSummary, onDismiss: { dismiss() }) {
                GameSummaryView(game: game)
            }
            .fullScreenCover(isPresented: $showingEndShiftSheet) {
                EndShiftScoreSheet(
                    teamScore: $shiftTeamScore,
                    opponentScore: $shiftOpponentScore,
                    startingTeamScore: activeShift?.startingTeamScore ?? 0,
                    startingOpponentScore: activeShift?.startingOpponentScore ?? 0,
                    onEnd: {
                        endCurrentShift()
                    }
                )
            }
            .fullScreenCover(isPresented: $showingPostShiftOverviewSheet) {
                if let shift = latestCompletedShift,
                   let selectedShiftPersonStats {
                    ShiftGameOverviewSheet(
                        shift: shift,
                        personGameStats: selectedShiftPersonStats,
                        game: game,
                        playerName: selectedShiftPlayerName,
                        onCloseTracking: {
                            dismiss()
                        },
                        onStartNextShift: {
                            startNewShiftFromPostShiftOverview()
                        },
                        onEndGame: {
                            endGameFromPostShiftOverview()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingShiftHistorySheet) {
                if let selectedShiftPersonStats {
                    ShiftHistorySheet(
                        personGameStats: selectedShiftPersonStats,
                        playerName: selectedShiftPlayerName,
                        onStartNextShift: {
                            startNewShiftFromShiftHistory()
                        }
                    )
                }
            }
            .overlay {
                if showMilestoneAnimation {
                    MilestoneOverlay(text: milestoneText)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                if selectedShiftPersonStatsID == nil {
                    selectedShiftPersonStatsID = preferredSelectedPersonStatsID(from: shiftTrackablePersonStats.map(\.id))
                }
                syncClockWithActiveShift()
                DispatchQueue.main.async {
                    bootstrapInitialShiftIfNeeded()
                    syncClockWithActiveShift()
                }
            }
            .onChange(of: shiftTrackablePersonStats.map(\.id)) { _, ids in
                guard let selectedShiftPersonStatsID else {
                    self.selectedShiftPersonStatsID = preferredSelectedPersonStatsID(from: ids)
                    syncClockWithActiveShift()
                    return
                }
                if !ids.contains(selectedShiftPersonStatsID) {
                    self.selectedShiftPersonStatsID = preferredSelectedPersonStatsID(from: ids)
                }
                bootstrapInitialShiftIfNeeded()
                syncClockWithActiveShift()
            }
            .onChange(of: selectedShiftPersonStatsID) { _, _ in
                bootstrapInitialShiftIfNeeded()
                syncClockWithActiveShift()
            }
            .onChange(of: activeShift?.id) { _, newShiftID in
                guard newShiftID != nil else { return }
                syncClockWithActiveShift()
            }
        }
    }

    @ViewBuilder
    private var shiftControls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Shift Tracking")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if shiftTrackablePersonStats.count > 1 {
                    Menu {
                        ForEach(shiftTrackablePersonStats) { personStats in
                            if let person = personStats.person {
                                Button {
                                    selectedShiftPersonStatsID = personStats.id
                                } label: {
                                    if selectedShiftPersonStatsID == personStats.id {
                                        Label(person.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(person.displayName)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedShiftPlayerName)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accent)
                    }
                } else {
                    Text(selectedShiftPlayerName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                toggleShift()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: activeShift == nil ? "play.fill" : "stop.fill")
                    Text(activeShift == nil ? "Start Shift" : "End Shift")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(activeShift == nil ? Color.green : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Label("\(totalShiftCount) \(totalShiftCount == 1 ? "shift" : "shifts")", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                Spacer()
                if let activeShift {
                    Label(activeShift.formattedDuration, systemImage: "clock")
                } else {
                    Label("Off court", systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if totalShiftCount > 0 {
                Button {
                    showingShiftHistorySheet = true
                } label: {
                    Label("View Shifts", systemImage: "list.bullet.rectangle.portrait")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
        }
        .padding(.horizontal)
    }

    private func preferredSelectedPersonStatsID(from availableIDs: [UUID]) -> UUID? {
        guard !availableIDs.isEmpty else { return nil }
        if let initialSelectedPersonStatsID,
           availableIDs.contains(initialSelectedPersonStatsID) {
            return initialSelectedPersonStatsID
        }
        return availableIDs.first
    }

    // MARK: - Basketball View

    private var basketballTrackingView: some View {
        VStack(spacing: 10) {
            // Score display
            HStack {
                Text("\(totalPoints)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.blue)
                Text("PTS")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Achievements inline
                if hasTripleDouble {
                    Label("Triple Double", systemImage: "star.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                } else if hasDoubleDouble {
                    Label("Double Double", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)

            // Shooting buttons - 3 across
            HStack(spacing: 10) {
                FlexStatButton(
                    title: "2 PTS",
                    subtitle: madeString("2PT"),
                    color: .blue,
                    action: { recordMade("2PT", points: 2) },
                    undoAction: { undoMade("2PT") }
                )
                FlexStatButton(
                    title: "3 PTS",
                    subtitle: madeString("3PT"),
                    color: .purple,
                    action: { recordMade("3PT", points: 3) },
                    undoAction: { undoMade("3PT") }
                )
                FlexStatButton(
                    title: "FT",
                    subtitle: madeString("FT"),
                    color: .orange,
                    action: { recordMade("FT", points: 1) },
                    undoAction: { undoMade("FT") }
                )
            }
            .padding(.horizontal)

            // Miss buttons
            HStack(spacing: 8) {
                MissButton(
                    title: "2PT Miss",
                    action: { recordMiss("2PT", points: 2) },
                    undoAction: { undoMiss("2PT") }
                )
                MissButton(
                    title: "3PT Miss",
                    action: { recordMiss("3PT", points: 3) },
                    undoAction: { undoMiss("3PT") }
                )
                MissButton(
                    title: "FT Miss",
                    action: { recordMiss("FT", points: 1) },
                    undoAction: { undoMiss("FT") }
                )
            }
            .padding(.horizontal)

            // Other stats - 3 columns, 2 rows
            HStack(spacing: 10) {
                FlexStatButton(title: "D-REB", subtitle: countString("DREB"), color: .green, action: { recordCount("DREB") }, undoAction: { undoCount("DREB") })
                FlexStatButton(title: "O-REB", subtitle: countString("OREB"), color: .teal, action: { recordCount("OREB") }, undoAction: { undoCount("OREB") })
                FlexStatButton(title: "STEAL", subtitle: countString("STL"), color: .indigo, action: { recordCount("STL") }, undoAction: { undoCount("STL") })
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                FlexStatButton(title: "ASSIST", subtitle: countString("AST"), color: .mint, action: { recordCount("AST") }, undoAction: { undoCount("AST") })
                FlexStatButton(title: "FOUL", subtitle: countString("PF"), color: .red, action: { recordCount("PF") }, undoAction: { undoCount("PF") })
                FlexStatButton(title: "MISSED DRIVE", subtitle: countString("MD"), color: .orange, action: { recordCount("MD") }, undoAction: { undoCount("MD") })
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                FlexStatButton(title: "BAD OFF", subtitle: countString("BPO"), color: .red, action: { recordCount("BPO") }, undoAction: { undoCount("BPO") })
                FlexStatButton(title: "BAD DEF", subtitle: countString("BPD"), color: .pink, action: { recordCount("BPD") }, undoAction: { undoCount("BPD") })
                FlexStatButton(title: "SUCCESS DRIVE", subtitle: countString("SD"), color: .green, action: { recordCount("SD") }, undoAction: { undoCount("SD") })
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                FlexStatButton(title: "GREAT OFF", subtitle: countString("GPO"), color: .yellow, action: { recordCount("GPO") }, undoAction: { undoCount("GPO") })
                FlexStatButton(title: "GREAT DEF", subtitle: countString("GPD"), color: .green, action: { recordCount("GPD") }, undoAction: { undoCount("GPD") })
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Soccer View

    private var soccerTrackingView: some View {
        VStack(spacing: 10) {
            // Goal display
            HStack {
                Text("\(totalGoals)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.green)
                Text("GOALS")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if totalSaves > 0 {
                    VStack(alignment: .trailing) {
                        Text("\(totalSaves)")
                            .font(.title.bold())
                            .foregroundStyle(.blue)
                        Text("Saves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            // Scoring stats
            HStack(spacing: 10) {
                FlexStatButton(title: "GOAL", subtitle: countString("GOL"), color: .green, action: { recordCount("GOL") }, undoAction: { undoCount("GOL") })
                FlexStatButton(title: "SHOT", subtitle: madeString("SOT"), color: .teal, action: { recordMade("SOT", points: 0) }, undoAction: { undoMade("SOT") })
                FlexStatButton(title: "ASSIST", subtitle: countString("AST"), color: .mint, action: { recordCount("AST") }, undoAction: { undoCount("AST") })
            }
            .padding(.horizontal)

            // Miss button for shots
            HStack(spacing: 8) {
                MissButton(
                    title: "Shot Off Target",
                    action: { recordMiss("SOT", points: 0) },
                    undoAction: { undoMiss("SOT") }
                )
            }
            .padding(.horizontal)

            // Defense stats
            HStack(spacing: 10) {
                FlexStatButton(title: "SAVE", subtitle: countString("SAV"), color: .blue, action: { recordCount("SAV") }, undoAction: { undoCount("SAV") })
                FlexStatButton(title: "TACKLE", subtitle: countString("TKL"), color: .indigo, action: { recordCount("TKL") }, undoAction: { undoCount("TKL") })
                FlexStatButton(title: "INT", subtitle: countString("INT"), color: .purple, action: { recordCount("INT") }, undoAction: { undoCount("INT") })
            }
            .padding(.horizontal)

            // Possession and other stats
            HStack(spacing: 10) {
                FlexStatButton(title: "PASS", subtitle: countString("PAS"), color: .cyan, action: { recordCount("PAS") }, undoAction: { undoCount("PAS") })
                FlexStatButton(title: "CORNER", subtitle: countString("CRN"), color: .orange, action: { recordCount("CRN") }, undoAction: { undoCount("CRN") })
                FlexStatButton(title: "FOUL", subtitle: countString("FLS"), color: .red, action: { recordCount("FLS") }, undoAction: { undoCount("FLS") })
            }
            .padding(.horizontal)

            // Cards
            HStack(spacing: 10) {
                FlexStatButton(title: "YELLOW", subtitle: countString("YC"), color: .yellow, action: { recordCount("YC") }, undoAction: { undoCount("YC") })
                FlexStatButton(title: "RED", subtitle: countString("RC"), color: .red, action: { recordCount("RC") }, undoAction: { undoCount("RC") })
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Timer

    private func toggleTimer() {
        timerRunning.toggle()
        if timerRunning && gameStartTime == nil {
            gameStartTime = Date()
        }
        impactLight.impactOccurred()
    }

    private func startClockIfNeeded() {
        guard !timerRunning else { return }
        timerRunning = true
        if gameStartTime == nil {
            gameStartTime = Date()
        }
    }

    private func syncClockWithActiveShift() {
        guard hasShiftTracking else { return }
        guard activeShift != nil else { return }
        startClockIfNeeded()
    }

    // MARK: - Undo

    private func performUndo() {
        guard let action = lastAction else { return }

        impactMedium.impactOccurred()

        switch action.type {
        case .made(let name, _):
            if let stat = game.stat(named: name), stat.made > 0 {
                stat.made -= 1
                if let shiftStat = activeShift?.statValue(forName: name), shiftStat.made > 0 {
                    shiftStat.made -= 1
                    shiftStat.timestamp = Date()
                }
                try? modelContext.save()
            }
        case .missed(let name, _):
            if let stat = game.stat(named: name), stat.missed > 0 {
                stat.missed -= 1
                if let shiftStat = activeShift?.statValue(forName: name), shiftStat.missed > 0 {
                    shiftStat.missed -= 1
                    shiftStat.timestamp = Date()
                }
                try? modelContext.save()
            }
        case .count(let name):
            if let stat = game.stat(named: name), stat.count > 0 {
                stat.count -= 1
                if let shiftStat = activeShift?.statValue(forName: name), shiftStat.count > 0 {
                    shiftStat.count -= 1
                    shiftStat.timestamp = Date()
                }
                try? modelContext.save()
            }
        }

        lastAction = nil

        // Show undo confirmation
        withAnimation {
            showingUndoToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showingUndoToast = false
            }
        }
    }

    // MARK: - Stat Recording

    private func toggleShift() {
        guard hasShiftTracking else { return }
        impactLight.impactOccurred()

        if let activeShift {
            shiftTeamScore = activeShift.startingTeamScore
            shiftOpponentScore = activeShift.startingOpponentScore
            showingEndShiftSheet = true
        } else {
            shiftTeamScore = lastKnownShiftTeamScore
            shiftOpponentScore = lastKnownShiftOpponentScore
            startNewShift()
        }
    }

    private func bootstrapInitialShiftIfNeeded() {
        guard hasShiftTracking else { return }
        guard !didBootstrapInitialShift else { return }
        guard let selectedShiftPersonStats else { return }

        let existingShifts = selectedShiftPersonStats.shifts ?? []
        guard existingShifts.isEmpty else {
            didBootstrapInitialShift = true
            return
        }

        shiftTeamScore = 0
        shiftOpponentScore = 0
        startNewShift()
        didBootstrapInitialShift = true
    }

    private func startNewShift() {
        guard let selectedShiftPersonStats else { return }
        guard selectedShiftPersonStats.currentShift == nil else { return }

        startClockIfNeeded()

        let shift = selectedShiftPersonStats.startNewShift(
            teamScore: shiftTeamScore,
            opponentScore: shiftOpponentScore
        )
        modelContext.insert(shift)
        try? modelContext.save()
    }

    private func endCurrentShift() {
        guard let selectedShiftPersonStats else { return }
        guard selectedShiftPersonStats.currentShift != nil else { return }

        selectedShiftPersonStats.endCurrentShift(
            teamScore: shiftTeamScore,
            opponentScore: shiftOpponentScore
        )
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showingPostShiftOverviewSheet = true
        }
    }

    private func startNewShiftFromShiftHistory() {
        showingShiftHistorySheet = false
        shiftTeamScore = lastKnownShiftTeamScore
        shiftOpponentScore = lastKnownShiftOpponentScore

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startNewShift()
        }
    }

    private func startNewShiftFromPostShiftOverview() {
        shiftTeamScore = lastKnownShiftTeamScore
        shiftOpponentScore = lastKnownShiftOpponentScore

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startNewShift()
        }
    }

    private func endGameFromPostShiftOverview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showingEndGameAlert = true
        }
    }

    private func getOrCreateStat(_ name: String, points: Int) -> Stat {
        if let existing = game.stat(named: name) {
            return existing
        }

        let stat = Stat(statName: name, pointValue: points)
        stat.game = game
        modelContext.insert(stat)

        if game.stats == nil { game.stats = [] }
        game.stats?.append(stat)

        return stat
    }

    private func getOrCreateActiveShiftStat(_ name: String, points: Int) -> ShiftStat? {
        guard let shift = activeShift else { return nil }

        if let existing = shift.statValue(forName: name) {
            return existing
        }

        let shiftStat = ShiftStat(statName: name, pointValue: points, shift: shift)
        modelContext.insert(shiftStat)

        if shift.stats == nil { shift.stats = [] }
        shift.stats?.append(shiftStat)

        return shiftStat
    }

    private func recordMade(_ name: String, points: Int) {
        impactMedium.impactOccurred()
        let oldDoubleDigits = doubleDigitCategories
        let stat = getOrCreateStat(name, points: points)
        stat.made += 1
        stat.timestamp = Date()

        if let shiftStat = getOrCreateActiveShiftStat(name, points: points) {
            shiftStat.made += 1
            shiftStat.timestamp = Date()
        }

        try? modelContext.save()

        // Save for undo
        lastAction = UndoAction(type: .made(statName: name, points: points), timestamp: Date())

        checkMilestones(oldDoubleDigits: oldDoubleDigits)
    }

    private func recordMiss(_ name: String, points: Int) {
        impactLight.impactOccurred()
        let stat = getOrCreateStat(name, points: points)
        stat.missed += 1
        stat.timestamp = Date()

        if let shiftStat = getOrCreateActiveShiftStat(name, points: points) {
            shiftStat.missed += 1
            shiftStat.timestamp = Date()
        }

        try? modelContext.save()

        // Save for undo
        lastAction = UndoAction(type: .missed(statName: name, points: points), timestamp: Date())
    }

    private func recordCount(_ name: String) {
        impactMedium.impactOccurred()
        let oldDoubleDigits = doubleDigitCategories
        let oldGoals = totalGoals
        let stat = getOrCreateStat(name, points: 0)
        stat.count += 1
        stat.timestamp = Date()

        if let shiftStat = getOrCreateActiveShiftStat(name, points: 0) {
            shiftStat.count += 1
            shiftStat.timestamp = Date()
        }

        try? modelContext.save()

        // Save for undo
        lastAction = UndoAction(type: .count(statName: name), timestamp: Date())

        checkMilestones(oldDoubleDigits: oldDoubleDigits)
        checkSoccerMilestones(oldGoals: oldGoals, statName: name)
    }

    private func undoMade(_ name: String) {
        guard let stat = game.stat(named: name), stat.made > 0 else { return }
        impactLight.impactOccurred()
        stat.made -= 1
        stat.timestamp = Date()

        if let shiftStat = activeShift?.statValue(forName: name), shiftStat.made > 0 {
            shiftStat.made -= 1
            shiftStat.timestamp = Date()
        }

        try? modelContext.save()
        lastAction = nil
    }

    private func undoMiss(_ name: String) {
        guard let stat = game.stat(named: name), stat.missed > 0 else { return }
        impactLight.impactOccurred()
        stat.missed -= 1
        stat.timestamp = Date()

        if let shiftStat = activeShift?.statValue(forName: name), shiftStat.missed > 0 {
            shiftStat.missed -= 1
            shiftStat.timestamp = Date()
        }

        try? modelContext.save()
        lastAction = nil
    }

    private func undoCount(_ name: String) {
        guard let stat = game.stat(named: name), stat.count > 0 else { return }
        impactLight.impactOccurred()
        stat.count -= 1
        stat.timestamp = Date()

        if let shiftStat = activeShift?.statValue(forName: name), shiftStat.count > 0 {
            shiftStat.count -= 1
            shiftStat.timestamp = Date()
        }

        try? modelContext.save()
        lastAction = nil
    }

    private func checkMilestones(oldDoubleDigits: Int) {
        let newDoubleDigits = doubleDigitCategories

        // Check for new double-double or triple-double (basketball)
        if newDoubleDigits >= 2 && oldDoubleDigits < 2 {
            celebrateMilestone("Double Double! 🔥")
        } else if newDoubleDigits >= 3 && oldDoubleDigits < 3 {
            celebrateMilestone("Triple Double! 🌟")
        }
    }

    private func checkSoccerMilestones(oldGoals: Int, statName: String) {
        guard isSoccer else { return }

        // Hat trick - 3 goals
        if statName == "GOL" && oldGoals == 2 && totalGoals == 3 {
            celebrateMilestone("Hat Trick! ⚽️⚽️⚽️")
        }
        // Poker - 4 goals
        else if statName == "GOL" && oldGoals == 3 && totalGoals == 4 {
            celebrateMilestone("Poker! 🃏⚽️")
        }
    }

    private func celebrateMilestone(_ text: String) {
        impactHeavy.impactOccurred()
        notificationFeedback.notificationOccurred(.success)
        milestoneText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showMilestoneAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showMilestoneAnimation = false
            }
        }
    }

    // MARK: - Display Helpers

    private func madeString(_ name: String) -> String {
        if let stat = game.stat(named: name) {
            return "\(stat.made)/\(stat.made + stat.missed)"
        }
        return "0/0"
    }

    private func countString(_ name: String) -> String {
        if let stat = game.stat(named: name) {
            return "\(stat.count)"
        }
        return "0"
    }
}

// MARK: - Components

struct FlexStatButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    let undoAction: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void,
        undoAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
        self.undoAction = undoAction
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.headline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: action)
        .onLongPressGesture(minimumDuration: 0.45) {
            undoAction?()
        }
        .accessibilityLabel("\(title), current: \(subtitle)")
        .accessibilityHint(undoAction == nil ? "Double tap to record" : "Double tap to record. Long press to undo one.")
        .accessibilityAddTraits(.isButton)
    }
}

struct MissButton: View {
    let title: String
    let action: () -> Void
    let undoAction: (() -> Void)?

    init(
        title: String,
        action: @escaping () -> Void,
        undoAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.action = action
        self.undoAction = undoAction
    }

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture(perform: action)
            .onLongPressGesture(minimumDuration: 0.45) {
                undoAction?()
            }
        .accessibilityLabel("Record \(title)")
        .accessibilityHint(undoAction == nil ? "Double tap to record a miss" : "Double tap to record. Long press to undo one.")
        .accessibilityAddTraits(.isButton)
    }
}

struct ShiftGameOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let shift: Shift
    let personGameStats: PersonGameStats
    let game: Game
    let playerName: String
    let onCloseTracking: () -> Void
    let onStartNextShift: () -> Void
    let onEndGame: () -> Void

    private struct SummaryMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let icon: String
        let tint: Color
    }

    private var isSoccer: Bool {
        game.sport?.name == "Soccer"
    }

    private var plusMinusColor: Color {
        guard let plusMinus = shift.plusMinus else { return .secondary }
        if plusMinus > 0 { return .green }
        if plusMinus < 0 { return .red }
        return .secondary
    }

    private var scoreLineText: String {
        let endingTeam = shift.endingTeamScore ?? shift.startingTeamScore
        let endingOpponent = shift.endingOpponentScore ?? shift.startingOpponentScore
        return "\(shift.startingTeamScore)-\(shift.startingOpponentScore) to \(endingTeam)-\(endingOpponent)"
    }

    private var summaryMetrics: [SummaryMetric] {
        if isSoccer {
            let shot = shift.statValue(forName: "SOT")
            let madeShots = shot?.made ?? 0
            let shotAttempts = madeShots + (shot?.missed ?? 0)

            return [
                SummaryMetric(title: "Goals", value: "\(shift.totalCount(forName: "GOL"))", icon: "soccerball", tint: .green),
                SummaryMetric(title: "Shots", value: "\(madeShots)/\(shotAttempts)", icon: "scope", tint: .teal),
                SummaryMetric(title: "Assists", value: "\(shift.totalCount(forName: "AST"))", icon: "arrow.triangle.branch", tint: .mint),
                SummaryMetric(title: "Saves", value: "\(shift.totalCount(forName: "SAV"))", icon: "hand.raised.square.fill", tint: .blue),
                SummaryMetric(title: "Tackles", value: "\(shift.totalCount(forName: "TKL"))", icon: "figure.fall", tint: .indigo),
                SummaryMetric(title: "Interceptions", value: "\(shift.totalCount(forName: "INT"))", icon: "hand.raised.fill", tint: .purple),
            ]
        }

        return [
            SummaryMetric(title: "Points", value: "\(shift.totalPoints)", icon: "basketball.fill", tint: .blue),
            SummaryMetric(title: "Rebounds", value: "\(shift.totalCount(forName: "DREB") + shift.totalCount(forName: "OREB"))", icon: "arrow.up.circle.fill", tint: .green),
            SummaryMetric(title: "Assists", value: "\(shift.totalCount(forName: "AST"))", icon: "arrow.triangle.branch", tint: .mint),
            SummaryMetric(title: "Steals", value: "\(shift.totalCount(forName: "STL"))", icon: "hand.raised.fill", tint: .indigo),
            SummaryMetric(title: "Fouls", value: "\(shift.totalCount(forName: "PF"))", icon: "exclamationmark.triangle.fill", tint: .red),
            SummaryMetric(title: "Missed Drive", value: "\(shift.totalCount(forName: "MD"))", icon: "xmark.circle.fill", tint: .orange),
            SummaryMetric(title: "Successful Drive", value: "\(shift.totalCount(forName: "SD"))", icon: "checkmark.circle.fill", tint: .green),
        ]
    }

    private var completedShiftsNewestFirst: [Shift] {
        Array(personGameStats.completedShifts.reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(game.isCompleted ? .gray : .green)
                            .frame(width: 10, height: 10)
                        Text(game.isCompleted ? "Ended" : "In Progress")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background((game.isCompleted ? Color.gray : Color.green).opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(playerName)
                            .font(.headline)
                        HStack {
                            Label("Shift \(shift.shiftNumber)", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                            Spacer()
                            Label(shift.formattedDuration, systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Score Swing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(scoreLineText)
                            .font(.headline)

                        HStack {
                            Text("Plus/Minus")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(shift.formattedPlusMinus)
                                .font(.title3.bold())
                                .foregroundStyle(plusMinusColor)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text(isSoccer ? "Soccer Snapshot" : "Basketball Snapshot")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(summaryMetrics) { metric in
                            VStack(alignment: .leading, spacing: 8) {
                                Label(metric.title, systemImage: metric.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(metric.value)
                                    .font(.title3.bold())
                                    .foregroundStyle(metric.tint)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if !completedShiftsNewestFirst.isEmpty {
                        Text("Shifts")
                            .font(.headline)

                        VStack(spacing: 10) {
                            ForEach(completedShiftsNewestFirst) { completedShift in
                                NavigationLink {
                                    ShiftEditView(shift: completedShift, playerName: playerName)
                                } label: {
                                    ShiftSummaryRow(shift: completedShift)
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        onStartNextShift()
                        dismiss()
                    } label: {
                        Label("Start New Shift", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(role: .destructive) {
                        onEndGame()
                        dismiss()
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
            .navigationTitle("Game Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        closeTrackingSession()
                    }
                }
            }
        }
    }

    private func closeTrackingSession() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onCloseTracking()
        }
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding()
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MilestoneOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 20)

                Text(text)
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
}

struct ShiftHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let personGameStats: PersonGameStats
    let playerName: String
    let onStartNextShift: () -> Void

    private var completedShiftsNewestFirst: [Shift] {
        Array(personGameStats.completedShifts.reversed())
    }

    private var totalShiftCount: Int {
        (personGameStats.shifts ?? []).count
    }

    private var totalPlusMinus: Int {
        personGameStats.completedShifts.compactMap(\.plusMinus).reduce(0, +)
    }

    private var formattedTotalPlusMinus: String {
        if totalPlusMinus > 0 { return "+\(totalPlusMinus)" }
        return "\(totalPlusMinus)"
    }

    private var totalPlusMinusColor: Color {
        if totalPlusMinus > 0 { return .green }
        if totalPlusMinus < 0 { return .red }
        return .secondary
    }

    private var canStartNewShift: Bool {
        personGameStats.currentShift == nil
    }

    var body: some View {
        NavigationStack {
            List {
                if let activeShift = personGameStats.currentShift {
                    Section("Current Shift") {
                        ShiftSummaryRow(shift: activeShift)
                    }
                }

                if !completedShiftsNewestFirst.isEmpty {
                    Section("Completed Shifts") {
                        ForEach(completedShiftsNewestFirst) { shift in
                            NavigationLink {
                                ShiftEditView(shift: shift, playerName: playerName)
                            } label: {
                                ShiftSummaryRow(shift: shift)
                            }
                        }
                    }
                }

                Section("Totals") {
                    LabeledContent("Shifts", value: "\(totalShiftCount)")
                    LabeledContent("Time on court", value: personGameStats.formattedTotalShiftTime)
                    LabeledContent("Points", value: "\(personGameStats.totalPointsFromShifts)")

                    HStack {
                        Text("Plus/Minus")
                        Spacer()
                        Text(formattedTotalPlusMinus)
                            .fontWeight(.bold)
                            .foregroundStyle(totalPlusMinusColor)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if canStartNewShift {
                    VStack(spacing: 10) {
                        Button {
                            onStartNextShift()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start New Shift")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("\(playerName) Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShiftEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var shift: Shift
    let playerName: String
    @State private var editableDurationSeconds: Int = 0

    private struct ShootingStatConfig {
        let name: String
        let title: String
        let points: Int
    }

    private struct CountStatConfig {
        let name: String
        let title: String
    }

    private let shootingStats: [ShootingStatConfig] = [
        ShootingStatConfig(name: "2PT", title: "2PT", points: 2),
        ShootingStatConfig(name: "3PT", title: "3PT", points: 3),
        ShootingStatConfig(name: "FT", title: "FT", points: 1),
    ]

    private let countStats: [CountStatConfig] = [
        CountStatConfig(name: "DREB", title: "Def Rebounds"),
        CountStatConfig(name: "OREB", title: "Off Rebounds"),
        CountStatConfig(name: "AST", title: "Assists"),
        CountStatConfig(name: "STL", title: "Steals"),
        CountStatConfig(name: "PF", title: "Fouls"),
        CountStatConfig(name: "MD", title: "Missed Drive"),
        CountStatConfig(name: "SD", title: "Successful Drive"),
        CountStatConfig(name: "BPO", title: "Bad Play Offense"),
        CountStatConfig(name: "BPD", title: "Bad Play Defense"),
        CountStatConfig(name: "GPO", title: "Great Play Offense"),
        CountStatConfig(name: "GPD", title: "Great Play Defense"),
    ]

    private var endingTeamScoreBinding: Binding<Int> {
        Binding(
            get: { shift.endingTeamScore ?? shift.startingTeamScore },
            set: { newValue in
                shift.endingTeamScore = max(0, newValue)
                save()
            }
        )
    }

    private var endingOpponentScoreBinding: Binding<Int> {
        Binding(
            get: { shift.endingOpponentScore ?? shift.startingOpponentScore },
            set: { newValue in
                shift.endingOpponentScore = max(0, newValue)
                save()
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { editableDurationSeconds },
            set: { newValue in
                editableDurationSeconds = max(0, newValue)
                shift.endTime = shift.startTime.addingTimeInterval(TimeInterval(editableDurationSeconds))
                save()
            }
        )
    }

    private var editableDurationText: String {
        let minutes = editableDurationSeconds / 60
        let seconds = editableDurationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Player", value: playerName)
                LabeledContent("Shift", value: "\(shift.shiftNumber)")
                LabeledContent("Duration", value: editableDurationText)
            }

            Section("Time On Court") {
                Stepper("Duration: \(editableDurationText)", value: durationBinding, in: 0...7200, step: 5)
                Text("Adjust if you forgot to stop the shift timer at the right moment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Score (Plus/Minus)") {
                Stepper("Start Team: \(shift.startingTeamScore)", value: $shift.startingTeamScore, in: 0...300)
                    .onChange(of: shift.startingTeamScore) { _, _ in save() }
                Stepper("Start Opponent: \(shift.startingOpponentScore)", value: $shift.startingOpponentScore, in: 0...300)
                    .onChange(of: shift.startingOpponentScore) { _, _ in save() }

                Stepper("End Team: \(endingTeamScoreBinding.wrappedValue)", value: endingTeamScoreBinding, in: 0...300)
                Stepper("End Opponent: \(endingOpponentScoreBinding.wrappedValue)", value: endingOpponentScoreBinding, in: 0...300)

                HStack {
                    Text("Plus/Minus")
                    Spacer()
                    Text(shift.formattedPlusMinus)
                        .fontWeight(.semibold)
                        .foregroundStyle(plusMinusColor)
                }

                Text("Plus/minus updates automatically from the start and end scores.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shooting") {
                ForEach(shootingStats, id: \.name) { stat in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(stat.title)
                            Spacer()
                            Text("\(madeValue(for: stat.name))/\(attemptsValue(for: stat.name))")
                                .foregroundStyle(.secondary)
                        }

                        Stepper("Made: \(madeValue(for: stat.name))", value: madeBinding(for: stat.name, points: stat.points), in: 0...200)
                        Stepper("Missed: \(missedValue(for: stat.name))", value: missedBinding(for: stat.name, points: stat.points), in: 0...200)
                    }
                }
            }

            Section("Other Stats") {
                ForEach(countStats, id: \.name) { stat in
                    Stepper("\(stat.title): \(countValue(for: stat.name))", value: countBinding(for: stat.name), in: 0...200)
                }
            }
        }
        .navigationTitle("Edit Shift \(shift.shiftNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    save()
                    dismiss()
                }
            }
        }
        .onAppear {
            editableDurationSeconds = max(0, Int(shift.duration.rounded()))
        }
    }

    private var plusMinusColor: Color {
        guard let plusMinus = shift.plusMinus else { return .secondary }
        if plusMinus > 0 { return .green }
        if plusMinus < 0 { return .red }
        return .secondary
    }

    private func madeValue(for name: String) -> Int {
        shift.statValue(forName: name)?.made ?? 0
    }

    private func missedValue(for name: String) -> Int {
        shift.statValue(forName: name)?.missed ?? 0
    }

    private func attemptsValue(for name: String) -> Int {
        madeValue(for: name) + missedValue(for: name)
    }

    private func countValue(for name: String) -> Int {
        shift.statValue(forName: name)?.count ?? 0
    }

    private func madeBinding(for name: String, points: Int) -> Binding<Int> {
        Binding(
            get: { madeValue(for: name) },
            set: { newValue in
                let stat = getOrCreateShiftStat(name: name, points: points)
                stat.made = max(0, newValue)
                cleanupShiftStatIfEmpty(stat)
                save()
            }
        )
    }

    private func missedBinding(for name: String, points: Int) -> Binding<Int> {
        Binding(
            get: { missedValue(for: name) },
            set: { newValue in
                let stat = getOrCreateShiftStat(name: name, points: points)
                stat.missed = max(0, newValue)
                cleanupShiftStatIfEmpty(stat)
                save()
            }
        )
    }

    private func countBinding(for name: String) -> Binding<Int> {
        Binding(
            get: { countValue(for: name) },
            set: { newValue in
                let stat = getOrCreateShiftStat(name: name, points: 0)
                stat.count = max(0, newValue)
                cleanupShiftStatIfEmpty(stat)
                save()
            }
        )
    }

    private func getOrCreateShiftStat(name: String, points: Int) -> ShiftStat {
        if let existing = shift.statValue(forName: name) {
            return existing
        }

        let stat = ShiftStat(statName: name, pointValue: points, shift: shift)
        modelContext.insert(stat)
        if shift.stats == nil { shift.stats = [] }
        shift.stats?.append(stat)
        return stat
    }

    private func cleanupShiftStatIfEmpty(_ stat: ShiftStat) {
        guard stat.made == 0 && stat.missed == 0 && stat.count == 0 else { return }
        shift.stats?.removeAll { $0.id == stat.id }
        modelContext.delete(stat)
    }

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    GameTrackingView(game: Game(opponent: "Lakers"))
        .modelContainer(for: [Game.self, Stat.self, Person.self, PersonGameStats.self, Shift.self], inMemory: true)
}
