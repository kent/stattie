import SwiftUI
import SwiftData
import UIKit

// MARK: - Undo Action

struct UndoAction {
    let statName: String
    let mutation: StatMutation
    let timestamp: Date
    let personGameStatsID: UUID?
    let shiftID: UUID?

    var description: String {
        switch mutation {
        case .made: return "\(statName) made"
        case .missed: return "\(statName) miss"
        case .count: return statName
        }
    }
}

struct GameTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    let initialSelectedPersonStatsID: UUID?
    @State private var selectedGamePosition: SoccerPosition?
    @State private var showingEndGameAlert = false
    @State private var showingSummary = false
    @State private var persistenceError: String?
    @State private var showMilestoneAnimation = false
    @State private var milestoneText = ""

    // Game timer
    @State private var clock = TrackingClock()
    @State private var clockTick = Date()
    private var timerRunning: Bool { clock.isRunning }

    // Undo support
    @State private var lastAction: UndoAction?
    @State private var showingUndoToast = false

    // Shift tracking flow
    @State private var showingStartShiftSheet = false
    @State private var showingEndShiftSheet = false
    @State private var showingShiftHistorySheet = false
    @State private var showingPostShiftOverviewSheet = false
    @State private var showingShiftPositionPicker = false
    @State private var selectedShiftPersonStatsID: UUID?
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

    private var isBasketball: Bool {
        game.sport?.name == "Basketball"
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
        (game.sport?.usesShiftTracking ?? true) && !shiftTrackablePersonStats.isEmpty
    }

    private var playerPositionAssignments: PositionAssignments {
        selectedShiftPersonStats?.person?.positionAssignments(for: game) ?? PositionAssignments()
    }

    private var assignedShiftPositions: [SoccerPosition] {
        playerPositionAssignments.positions(for: game.sport?.name)
    }

    private var canChooseShiftPosition: Bool {
        !SoccerPosition.positions(for: SoccerPosition.supportedSport(for: game.sport?.name)).isEmpty
    }

    private var activeTrackingPosition: SoccerPosition? {
        activeShift?.recordedPosition ?? selectedGamePosition
    }

    private var totalShiftCount: Int {
        (selectedShiftPersonStats?.shifts ?? []).count
    }

    private var latestCompletedShift: Shift? {
        selectedShiftPersonStats?.completedShifts.last
    }

    private var lastKnownShiftTeamScore: Int {
        guard let latest = selectedShiftPersonStats?.completedShifts.last else { return 0 }
        return latest.endingTeamScore ?? latest.startingTeamScore
    }

    private var lastKnownShiftOpponentScore: Int {
        guard let latest = selectedShiftPersonStats?.completedShifts.last else { return 0 }
        return latest.endingOpponentScore ?? latest.startingOpponentScore
    }

    private var shouldShowActiveShiftStats: Bool {
        activeShift != nil
    }

    private var displayedBasketballPoints: Int {
        shouldShowActiveShiftStats ? (activeShift?.totalPoints ?? 0) : totalPoints
    }

    private var displayedSoccerGoals: Int {
        shouldShowActiveShiftStats ? (activeShift?.totalCount(forName: "GOL") ?? 0) : totalGoals
    }

    private var displayedSoccerSaves: Int {
        shouldShowActiveShiftStats ? (activeShift?.totalCount(forName: "SAV") ?? 0) : totalSaves
    }

    private var displayedSoccerPrimaryValue: Int {
        activeTrackingPosition?.isGoalkeeperRole == true ? displayedSoccerSaves : displayedSoccerGoals
    }

    private var displayedSoccerPrimaryLabel: String {
        if activeTrackingPosition?.isGoalkeeperRole == true {
            return shouldShowActiveShiftStats ? "SHIFT SAVES" : "SAVES"
        }
        return shouldShowActiveShiftStats ? "SHIFT GOALS" : "GOALS"
    }

    var totalPoints: Int {
        game.totalPoints
    }

    // Basketball stats
    var totalRebounds: Int {
        game.totalCount(forName: "DREB") + game.totalCount(forName: "OREB")
    }

    var totalAssists: Int {
        game.totalCount(forName: "AST")
    }

    var totalSteals: Int {
        game.totalCount(forName: "STL")
    }

    // Soccer stats
    var totalGoals: Int {
        game.totalCount(forName: "GOL")
    }

    var totalSaves: Int {
        game.totalCount(forName: "SAV")
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
        isBasketball && doubleDigitCategories >= 2
    }

    var hasTripleDouble: Bool {
        isBasketball && doubleDigitCategories >= 3
    }

    private var formattedTime: String {
        let elapsed = Int(clock.elapsed(at: clockTick))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init(
        game: Game,
        initialSelectedPersonStatsID: UUID? = nil,
        initialSelectedPosition: SoccerPosition? = nil
    ) {
        self._game = Bindable(game)
        self.initialSelectedPersonStatsID = initialSelectedPersonStatsID
        self._selectedGamePosition = State(initialValue: initialSelectedPosition)
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

                if hasShiftTracking || canChooseShiftPosition {
                    shiftPositionPickerButton
                }

                if hasShiftTracking {
                    shiftControls
                }

                if isSoccer {
                    soccerTrackingView
                } else if isBasketball {
                    basketballTrackingView
                } else {
                    genericTrackingView
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
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                if timerRunning { clockTick = date }
            }
            .alert("End Game?", isPresented: $showingEndGameAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Game", role: .destructive) {
                    finalizeGame()
                }
            } message: {
                Text("This will mark the game as completed.")
            }
            .errorAlert(title: "Couldn’t Save", message: $persistenceError)
            .sheet(isPresented: $showingSummary, onDismiss: { dismiss() }) {
                GameSummaryView(game: game)
            }
            .fullScreenCover(isPresented: $showingStartShiftSheet) {
                StartShiftScoreSheet(
                    teamScore: $shiftTeamScore,
                    opponentScore: $shiftOpponentScore,
                    sportName: game.sport?.name,
                    assignedPositions: assignedShiftPositions,
                    selectedPosition: $selectedGamePosition,
                    onStart: {
                        startNewShift()
                    }
                )
            }
            .sheet(isPresented: $showingShiftPositionPicker) {
                ShiftPositionPickerSheet(
                    sportName: game.sport?.name,
                    assignedPositions: assignedShiftPositions,
                    playerName: selectedShiftPlayerName,
                    confirmTitle: activeShift == nil ? "Use Position" : "Update Shift",
                    selectedPosition: $selectedGamePosition,
                    onConfirm: {
                        applySelectedPositionToActiveShift()
                    }
                )
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
                do {
                    _ = try StatAttributionMigration.migrateLegacyShiftStats(in: modelContext)
                } catch {
                    persistenceError = error.localizedDescription
                }
                if selectedShiftPersonStatsID == nil {
                    selectedShiftPersonStatsID = preferredSelectedPersonStatsID(from: shiftTrackablePersonStats.map(\.id))
                }
                seedShiftPositionIfNeeded()
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
                seedShiftPositionIfNeeded(force: true)
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
    private var shiftPositionPickerButton: some View {
        Button {
            showingShiftPositionPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: activeTrackingPosition?.iconName ?? "figure.run")
                Text(activeTrackingPosition.map { "\(activeShift == nil ? "Next shift" : "This shift"): \($0.displayName)" } ?? "Choose position for this shift")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel("Shift position")
        .accessibilityValue(activeTrackingPosition?.displayName ?? "None selected")
        .accessibilityHint("Double tap to choose the position for this shift")
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

    private func seedShiftPositionIfNeeded(force: Bool = false) {
        if let activeShiftPosition = activeShift?.recordedPosition {
            selectedGamePosition = activeShiftPosition
            return
        }
        guard force || selectedGamePosition == nil else { return }
        if let lastPosition = selectedShiftPersonStats?.completedShifts.last(where: { $0.recordedPosition != nil })?.recordedPosition {
            selectedGamePosition = lastPosition
            return
        }
        selectedGamePosition = playerPositionAssignments.primaryPosition ?? assignedShiftPositions.first
    }

    private func applySelectedPositionToActiveShift() {
        guard let activeShift, let selectedGamePosition else { return }
        activeShift.recordedPosition = selectedGamePosition
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
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
                Text("\(displayedBasketballPoints)")
                    .scaledFont(size: 56, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.blue)
                Text(shouldShowActiveShiftStats ? "SHIFT PTS" : "PTS")
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
                RecordingStatButton(
                    title: "2 PTS",
                    subtitle: displayMadeString("2PT"),
                    color: .blue,
                    action: { recordMade("2PT", points: 2) },
                    undoAction: { undoMade("2PT") }
                )
                RecordingStatButton(
                    title: "3 PTS",
                    subtitle: displayMadeString("3PT"),
                    color: .purple,
                    action: { recordMade("3PT", points: 3) },
                    undoAction: { undoMade("3PT") }
                )
                RecordingStatButton(
                    title: "FT",
                    subtitle: displayMadeString("FT"),
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

            // Other stats - 3 columns
            HStack(spacing: 10) {
                RecordingStatButton(title: "D-REB", subtitle: displayCountString("DREB"), color: .green, action: { recordCount("DREB") }, undoAction: { undoCount("DREB") })
                RecordingStatButton(title: "O-REB", subtitle: displayCountString("OREB"), color: .teal, action: { recordCount("OREB") }, undoAction: { undoCount("OREB") })
                RecordingStatButton(title: "STEAL", subtitle: displayCountString("STL"), color: .indigo, action: { recordCount("STL") }, undoAction: { undoCount("STL") })
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                RecordingStatButton(title: "ASSIST", subtitle: displayCountString("AST"), color: .mint, action: { recordCount("AST") }, undoAction: { undoCount("AST") })
                RecordingStatButton(title: "FOUL", subtitle: displayCountString("PF"), color: .red, action: { recordCount("PF") }, undoAction: { undoCount("PF") })
                RecordingStatButton(title: "TURNOVER", subtitle: displayCountString("TO"), color: .brown, action: { recordCount("TO") }, undoAction: { undoCount("TO") })
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                RecordingStatButton(title: "MISSED DRIVE", subtitle: displayCountString("MD"), color: .orange, action: { recordCount("MD") }, undoAction: { undoCount("MD") })
                RecordingStatButton(title: "BAD OFF", subtitle: displayCountString("BPO"), color: .red, action: { recordCount("BPO") }, undoAction: { undoCount("BPO") })
                RecordingStatButton(title: "BAD DEF", subtitle: displayCountString("BPD"), color: .pink, action: { recordCount("BPD") }, undoAction: { undoCount("BPD") })
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                RecordingStatButton(title: "SUCCESS DRIVE", subtitle: displayCountString("SD"), color: .green, action: { recordCount("SD") }, undoAction: { undoCount("SD") })
                RecordingStatButton(title: "GREAT OFF", subtitle: displayCountString("GPO"), color: .yellow, action: { recordCount("GPO") }, undoAction: { undoCount("GPO") })
                RecordingStatButton(title: "GREAT DEF", subtitle: displayCountString("GPD"), color: .green, action: { recordCount("GPD") }, undoAction: { undoCount("GPD") })
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
                Text("\(displayedSoccerPrimaryValue)")
                    .scaledFont(size: 56, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(activeTrackingPosition?.isGoalkeeperRole == true ? .blue : .green)
                Text(displayedSoccerPrimaryLabel)
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if activeTrackingPosition?.isGoalkeeperRole != true, totalSaves > 0 {
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

            if showsSoccerStat("GOL") || showsSoccerStat("SOT") || showsSoccerStat("AST") {
                HStack(spacing: 10) {
                    if showsSoccerStat("GOL") {
                        RecordingStatButton(title: "GOAL", subtitle: displayCountString("GOL"), color: .green, action: { recordCount("GOL") }, undoAction: { undoCount("GOL") })
                    }
                    if showsSoccerStat("SOT") {
                        RecordingStatButton(title: "SHOT", subtitle: displayMadeString("SOT"), color: .teal, action: { recordMade("SOT", points: 0) }, undoAction: { undoMade("SOT") })
                    }
                    if showsSoccerStat("AST") {
                        RecordingStatButton(title: "ASSIST", subtitle: displayCountString("AST"), color: .mint, action: { recordCount("AST") }, undoAction: { undoCount("AST") })
                    }
                }
                .padding(.horizontal)
            }

            if showsSoccerStat("SOT") {
                HStack(spacing: 8) {
                    MissButton(
                        title: "Shot Off Target",
                        action: { recordMiss("SOT", points: 0) },
                        undoAction: { undoMiss("SOT") }
                    )
                }
                .padding(.horizontal)
            }

            if showsSoccerStat("SAV") || showsSoccerStat("TKL") || showsSoccerStat("INT") {
                HStack(spacing: 10) {
                    if showsSoccerStat("SAV") {
                        RecordingStatButton(title: "SAVE", subtitle: displayCountString("SAV"), color: .blue, action: { recordCount("SAV") }, undoAction: { undoCount("SAV") })
                    }
                    if showsSoccerStat("TKL") {
                        RecordingStatButton(title: "TACKLE", subtitle: displayCountString("TKL"), color: .indigo, action: { recordCount("TKL") }, undoAction: { undoCount("TKL") })
                    }
                    if showsSoccerStat("INT") {
                        RecordingStatButton(title: "INT", subtitle: displayCountString("INT"), color: .purple, action: { recordCount("INT") }, undoAction: { undoCount("INT") })
                    }
                }
                .padding(.horizontal)
            }

            if showsSoccerStat("PAS") || showsSoccerStat("CRN") || showsSoccerStat("FLS") {
                HStack(spacing: 10) {
                    if showsSoccerStat("PAS") {
                        RecordingStatButton(title: "PASS", subtitle: displayCountString("PAS"), color: .cyan, action: { recordCount("PAS") }, undoAction: { undoCount("PAS") })
                    }
                    if showsSoccerStat("CRN") {
                        RecordingStatButton(title: "CORNER", subtitle: displayCountString("CRN"), color: .orange, action: { recordCount("CRN") }, undoAction: { undoCount("CRN") })
                    }
                    if showsSoccerStat("FLS") {
                        RecordingStatButton(title: "FOUL", subtitle: displayCountString("FLS"), color: .red, action: { recordCount("FLS") }, undoAction: { undoCount("FLS") })
                    }
                }
                .padding(.horizontal)
            }

            if showsSoccerStat("YC") || showsSoccerStat("RC") {
                HStack(spacing: 10) {
                    if showsSoccerStat("YC") {
                        RecordingStatButton(title: "YELLOW", subtitle: displayCountString("YC"), color: .yellow, action: { recordCount("YC") }, undoAction: { undoCount("YC") })
                    }
                    if showsSoccerStat("RC") {
                        RecordingStatButton(title: "RED", subtitle: displayCountString("RC"), color: .red, action: { recordCount("RC") }, undoAction: { undoCount("RC") })
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Individual / Generic Sports

    private var trackingPositions: [SoccerPosition] {
        if let activeTrackingPosition {
            return [activeTrackingPosition]
        }
        return assignedShiftPositions
    }

    private func showsSoccerStat(_ shortName: String) -> Bool {
        SportCatalog.showsStat(
            shortName,
            sportName: game.sport?.name,
            positions: trackingPositions
        )
    }

    private var genericVisibleDefinitions: [StatDefinition] {
        SportCatalog.visibleDefinitions(
            sportName: game.sport?.name,
            definitions: game.sport?.sortedStatDefinitions ?? [],
            positions: trackingPositions
        )
    }

    private var genericShootingDefinitions: [StatDefinition] {
        genericVisibleDefinitions.filter(\.hasMadeAndMissed)
    }

    private var genericCountDefinitions: [StatDefinition] {
        genericVisibleDefinitions.filter { !$0.hasMadeAndMissed }
    }

    private var genericPrimaryDefinition: StatDefinition? {
        if let profile = SportCatalog.profile(named: game.sport?.name) {
            switch profile.primaryScore {
            case .count(let shortName), .made(let shortName):
                return genericVisibleDefinitions.first { $0.shortName == shortName }
                    ?? game.sport?.sortedStatDefinitions.first { $0.shortName == shortName }
            case .points:
                break
            }
        }
        return genericVisibleDefinitions.first ?? game.sport?.sortedStatDefinitions.first
    }

    private var genericPrimaryValue: Int {
        guard let definition = genericPrimaryDefinition else { return game.totalPoints }
        if definition.hasMadeAndMissed {
            return displayedStats.totalMade(forName: definition.shortName)
        }
        return displayedStats.totalCount(forName: definition.shortName)
    }

    private var genericTrackingView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let definition = genericPrimaryDefinition {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(genericPrimaryValue)")
                            .scaledFont(size: 56, weight: .bold, relativeTo: .largeTitle)
                            .foregroundStyle(.blue)
                        Text(definition.name.uppercased())
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                ForEach(genericShootingDefinitions, id: \.id) { definition in
                    ShootingStatButton(
                        definition: definition,
                        made: displayedStats.totalMade(forName: definition.shortName),
                        missed: displayedStats.totalMissed(forName: definition.shortName),
                        onMade: { recordMade(definition.shortName, points: definition.pointValue) },
                        onMissed: { recordMiss(definition.shortName, points: definition.pointValue) }
                    )
                    .padding(.horizontal)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(genericCountDefinitions, id: \.id) { definition in
                        CountStatButton(
                            definition: definition,
                            count: displayedStats.totalCount(forName: definition.shortName),
                            onTap: { recordCount(definition.shortName) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displayedStats: any StatProviding {
        if let activeShift { return activeShift }
        return game
    }

    // MARK: - Timer

    private func toggleTimer() {
        clockTick = Date()
        if timerRunning { clock.pause(at: clockTick) } else { clock.start(at: clockTick) }
        impactLight.impactOccurred()
    }

    private func startClockIfNeeded() {
        clockTick = Date()
        clock.start(at: clockTick)
    }

    private func syncClockWithActiveShift() {
        guard hasShiftTracking else { return }
        guard activeShift != nil else { return }
        startClockIfNeeded()
    }

    // MARK: - Undo

    private func performUndo() {
        guard let action = lastAction else { return }
        let personGameStats = (game.personStats ?? []).first { $0.id == action.personGameStatsID }
        let shift = (personGameStats?.shifts ?? []).first { $0.id == action.shiftID }
        guard action.personGameStatsID == nil || personGameStats != nil,
              action.shiftID == nil || shift != nil else {
            lastAction = nil
            persistenceError = "The original player or shift no longer exists, so this action can’t be undone safely."
            return
        }


        do {
            guard try game.undoStat(
                named: action.statName,
                mutation: action.mutation,
                personGameStats: personGameStats,
                shift: shift
            ) else { return }
            try modelContext.save()
            impactMedium.impactOccurred()
            lastAction = nil
            withAnimation { showingUndoToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showingUndoToast = false }
            }
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
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
            showingStartShiftSheet = true
        }
    }

    private func bootstrapInitialShiftIfNeeded() {
        guard hasShiftTracking else { return }
        guard selectedShiftPersonStats != nil else { return }

        shiftTeamScore = lastKnownShiftTeamScore
        shiftOpponentScore = lastKnownShiftOpponentScore
    }

    private func startNewShift() {
        guard let selectedShiftPersonStats else { return }
        guard selectedShiftPersonStats.currentShift == nil else { return }

        let previousShifts = selectedShiftPersonStats.shifts
        let previousClock = clock
        startClockIfNeeded()

        let shift = selectedShiftPersonStats.startNewShift(
            teamScore: shiftTeamScore,
            opponentScore: shiftOpponentScore,
            position: selectedGamePosition ?? assignedShiftPositions.first
        )
        modelContext.insert(shift)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            selectedShiftPersonStats.shifts = previousShifts
            clock = previousClock
            persistenceError = error.localizedDescription
        }
    }

    private func endCurrentShift() {
        guard let selectedShiftPersonStats,
              let shift = selectedShiftPersonStats.currentShift else { return }

        let endTime = shift.endTime
        let endingTeamScore = shift.endingTeamScore
        let endingOpponentScore = shift.endingOpponentScore
        selectedShiftPersonStats.endCurrentShift(
            teamScore: shiftTeamScore,
            opponentScore: shiftOpponentScore
        )
        do {
            try modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showingPostShiftOverviewSheet = true
            }
        } catch {
            modelContext.rollback()
            shift.endTime = endTime
            shift.endingTeamScore = endingTeamScore
            shift.endingOpponentScore = endingOpponentScore
            persistenceError = error.localizedDescription
        }
    }

    private func startNewShiftFromShiftHistory() {
        showingShiftHistorySheet = false
        shiftTeamScore = lastKnownShiftTeamScore
        shiftOpponentScore = lastKnownShiftOpponentScore

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingStartShiftSheet = true
        }
    }

    private func startNewShiftFromPostShiftOverview() {
        shiftTeamScore = lastKnownShiftTeamScore
        shiftOpponentScore = lastKnownShiftOpponentScore

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingStartShiftSheet = true
        }
    }

    private func endGameFromPostShiftOverview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showingEndGameAlert = true
        }
    }

    private var currentStatPersonAttribution: PersonGameStats? {
        selectedShiftPersonStats
    }

    private func recordMade(_ name: String, points: Int) {
        recordStat(name, points: points, mutation: .made)
    }

    private func recordMiss(_ name: String, points: Int) {
        recordStat(name, points: points, mutation: .missed)
    }

    private func recordCount(_ name: String) {
        recordStat(name, points: 0, mutation: .count)
    }

    private func recordStat(_ name: String, points: Int, mutation: StatMutation) {
        let oldDoubleDigits = doubleDigitCategories
        let oldGoals = totalGoals
        let person = currentStatPersonAttribution
        let shift = activeShift
        do {
            try game.recordStat(
                named: name, pointValue: points, mutation: mutation,
                personGameStats: person, shift: shift, in: modelContext
            )
            try modelContext.save()
            lastAction = UndoAction(
                statName: name, mutation: mutation, timestamp: Date(),
                personGameStatsID: person?.id, shiftID: shift?.id
            )
            if mutation == .missed {
                impactLight.impactOccurred()
            } else {
                impactMedium.impactOccurred()
                checkMilestones(oldDoubleDigits: oldDoubleDigits)
                if mutation == .count { checkSoccerMilestones(oldGoals: oldGoals, statName: name) }
            }
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    private func undoMade(_ name: String) {
        undoStat(name, mutation: .made)
    }

    private func undoMiss(_ name: String) {
        undoStat(name, mutation: .missed)
    }

    private func undoCount(_ name: String) {
        undoStat(name, mutation: .count)
    }

    private func undoStat(_ name: String, mutation: StatMutation) {
        do {
            guard try game.undoStat(
                named: name,
                mutation: mutation,
                personGameStats: currentStatPersonAttribution,
                shift: activeShift
            ) else { return }
            try modelContext.save()
            impactLight.impactOccurred()
            lastAction = nil
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    private func finalizeGame() {
        do {
            _ = try game.finalize(
                in: modelContext,
                teamScore: shiftTeamScore,
                opponentScore: shiftOpponentScore
            )
            showingSummary = true
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func checkMilestones(oldDoubleDigits: Int) {
        guard isBasketball else { return }
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
        let made = game.totalMade(forName: name)
        return "\(made)/\(made + game.totalMissed(forName: name))"
    }

    private func countString(_ name: String) -> String {
        "\(game.totalCount(forName: name))"
    }

    private func activeShiftMadeString(_ name: String) -> String {
        activeShift?.madeString(forName: name) ?? "0/0"
    }

    private func activeShiftCountString(_ name: String) -> String {
        "\(activeShift?.totalCount(forName: name) ?? 0)"
    }

    private func displayMadeString(_ name: String) -> String {
        shouldShowActiveShiftStats ? activeShiftMadeString(name) : madeString(name)
    }

    private func displayCountString(_ name: String) -> String {
        shouldShowActiveShiftStats ? activeShiftCountString(name) : countString(name)
    }
}

// MARK: - Components
