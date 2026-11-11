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
    @State private var showingShiftManager = false
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
        game.shiftPlayers
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

    private var totalGoals: Int {
        game.totalCount(forName: "GOL")
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

                StatBoardView(
                    sport: game.sport,
                    position: activeTrackingPosition,
                    visiblePositions: trackingPositions,
                    stats: displayedStats,
                    contextStats: game,
                    isShiftScoped: activeShift != nil,
                    record: { recordStat($0, points: $1, mutation: $2) },
                    undo: { undoStat($0, mutation: $1) }
                )
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
                        requestEndGame()
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
            .errorAlert(title: "Couldn’t Save", message: Binding(
                get: { showingStartShiftSheet || showingShiftPositionPicker ? nil : persistenceError },
                set: { persistenceError = $0 }
            ))
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
                .errorAlert(title: "Couldn’t Start Shift", message: $persistenceError)
            }
            .sheet(isPresented: $showingShiftPositionPicker) {
                if activeShift != nil {
                    StartShiftScoreSheet(
                        teamScore: $shiftTeamScore,
                        opponentScore: $shiftOpponentScore,
                        sportName: game.sport?.name,
                        assignedPositions: assignedShiftPositions,
                        selectedPosition: $selectedGamePosition,
                        isPositionChange: true,
                        previousPosition: activeShift?.recordedPosition,
                        onStart: changeActivePosition
                    )
                    .errorAlert(title: "Couldn’t Change Position", message: $persistenceError)
                } else {
                    ShiftPositionPickerSheet(
                        sportName: game.sport?.name,
                        assignedPositions: assignedShiftPositions,
                        playerName: selectedShiftPlayerName,
                        confirmTitle: "Use Position",
                        selectedPosition: $selectedGamePosition
                    )
                }
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
            .sheet(isPresented: $showingShiftManager, onDismiss: {
                if game.isCompleted { showingSummary = true }
            }) {
                ManageShiftsView(game: game)
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
            .onChange(of: selectedShiftPersonStatsID) { previousID, _ in
                seedShiftPositionIfNeeded(force: previousID != nil)
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
            if let activeShift {
                selectedGamePosition = activeShift.recordedPosition
                shiftTeamScore = activeShift.startingTeamScore
                shiftOpponentScore = activeShift.startingOpponentScore
            }
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

            Button {
                showingShiftManager = true
            } label: {
                Label("Manage Shifts", systemImage: "list.bullet.rectangle.portrait")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.accent)
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
        selectedGamePosition = playerPositionAssignments.startingPosition(for: game.sport?.name)
    }

    private func changeActivePosition() -> Bool {
        guard let selectedShiftPersonStats, let selectedGamePosition else { return false }
        do {
            _ = try selectedShiftPersonStats.changePosition(
                to: selectedGamePosition,
                teamScore: shiftTeamScore,
                opponentScore: shiftOpponentScore,
                in: modelContext
            )
            return true
        } catch {
            persistenceError = error.localizedDescription
            return false
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

    // MARK: - Stat Board

    private var trackingPositions: [SoccerPosition] {
        if let activeTrackingPosition {
            return [activeTrackingPosition]
        }
        return assignedShiftPositions
    }

    private var displayedStats: any StatTotals {
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

    private func startNewShift() -> Bool {
        guard let selectedShiftPersonStats,
              selectedShiftPersonStats.currentShift == nil,
              assignedShiftPositions.count <= 1 || selectedGamePosition != nil else { return false }

        let previousShifts = selectedShiftPersonStats.shifts
        let previousClock = clock
        startClockIfNeeded()

        let shift = selectedShiftPersonStats.startNewShift(
            teamScore: shiftTeamScore,
            opponentScore: shiftOpponentScore,
            position: selectedGamePosition ?? playerPositionAssignments.startingPosition(for: game.sport?.name)
        )
        modelContext.insert(shift)
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            selectedShiftPersonStats.shifts = previousShifts
            clock = previousClock
            persistenceError = error.localizedDescription
            return false
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
            selectedGamePosition = playerPositionAssignments.startingPosition(for: game.sport?.name)
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

    private func startNewShiftFromPostShiftOverview() {
        shiftTeamScore = lastKnownShiftTeamScore
        shiftOpponentScore = lastKnownShiftOpponentScore

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showingStartShiftSheet = true
        }
    }

    private func endGameFromPostShiftOverview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            requestEndGame()
        }
    }

    /// Shift sports review shifts before finalizing; others confirm directly.
    private func requestEndGame() {
        if hasShiftTracking {
            showingShiftManager = true
        } else {
            showingEndGameAlert = true
        }
    }

    private var currentStatPersonAttribution: PersonGameStats? {
        selectedShiftPersonStats
    }

    private func recordStat(_ name: String, points: Int, mutation: StatMutation) {
        let oldDoubleDigits = game.doubleDigitCategories
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
        let newDoubleDigits = game.doubleDigitCategories

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
}

// MARK: - Components
