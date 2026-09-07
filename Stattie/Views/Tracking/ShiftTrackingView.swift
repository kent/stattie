import SwiftUI
import SwiftData
import UIKit

/// View for tracking stats per shift for a person in a game
struct ShiftTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var personGameStats: PersonGameStats
    @State private var showingEndShiftSheet = false
    @State private var showingStartShiftSheet = false
    @State private var showingPositionConfirmation = false
    @State private var selectedShiftPosition: SoccerPosition?
    @State private var persistenceError: String?

    // Score tracking
    @State private var teamScore: Int = 0
    @State private var opponentScore: Int = 0

    // Last known scores (to auto-populate for next shift)
    private var lastKnownTeamScore: Int {
        guard let latest = personGameStats.completedShifts.last else { return 0 }
        return latest.endingTeamScore ?? latest.startingTeamScore
    }
    private var lastKnownOpponentScore: Int {
        guard let latest = personGameStats.completedShifts.last else { return 0 }
        return latest.endingOpponentScore ?? latest.startingOpponentScore
    }

    private var currentShift: Shift? {
        personGameStats.currentShift
    }

    private var isOnCourt: Bool {
        currentShift != nil
    }

    private var shiftDuration: String {
        currentShift?.formattedDuration ?? "0:00"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Shift status header
                shiftStatusHeader

                if isOnCourt {
                    // Active shift - show stat buttons
                    shiftStatsView
                } else {
                    // Not on court - show summary of shifts
                    offCourtView
                }
            }
            .navigationTitle(personGameStats.person?.displayName ?? "Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStartShiftSheet) {
                StartShiftScoreSheet(
                    teamScore: $teamScore,
                    opponentScore: $opponentScore,
                    sportName: personGameStats.game?.sport?.name,
                    assignedPositions: playerPositionAssignments.positions(for: personGameStats.game?.sport?.name),
                    selectedPosition: $selectedShiftPosition,
                    onStart: {
                        startNewShift()
                    }
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingEndShiftSheet) {
                EndShiftScoreSheet(
                    teamScore: $teamScore,
                    opponentScore: $opponentScore,
                    startingTeamScore: currentShift?.startingTeamScore ?? 0,
                    startingOpponentScore: currentShift?.startingOpponentScore ?? 0,
                    onEnd: {
                        endCurrentShift()
                    }
                )
                .presentationDetents([.medium])
            }
            .errorAlert(title: "Couldn’t Save", message: $persistenceError)
            .sheet(isPresented: $showingPositionConfirmation) {
                ShiftPositionPickerSheet(
                    sportName: personGameStats.game?.sport?.name,
                    assignedPositions: playerPositionAssignments.positions(for: personGameStats.game?.sport?.name),
                    playerName: personGameStats.person?.displayName ?? "Player",
                    confirmTitle: "Continue",
                    selectedPosition: $selectedShiftPosition,
                    onConfirm: {
                        showingPositionConfirmation = false
                        showingStartShiftSheet = true
                    }
                )
            }
        }
    }

    // MARK: - Position Helpers

    /// Check if the player has multiple positions defined (on team or person level)
    private var hasMultiplePositions: Bool {
        playerPositionAssignments.assignments.count > 1
    }

    /// Get position assignments - prioritize team membership, fall back to person
    private var playerPositionAssignments: PositionAssignments {
        // Check if person is part of a team with the game
        if let game = personGameStats.game,
           let team = game.team,
           let person = personGameStats.person,
           let membership = team.memberships?.first(where: { $0.person?.id == person.id && $0.isActive }) {
            if !membership.positionAssignments.isEmpty {
                return membership.positionAssignments
            }
        }

        // Fall back to person's default positions
        return personGameStats.person?.positionAssignments ?? PositionAssignments()
    }

    // MARK: - Shift Status Header

    @ViewBuilder
    private var shiftStatusHeader: some View {
        VStack(spacing: 8) {
            HStack {
                // On/Off status indicator
                Circle()
                    .fill(isOnCourt ? .green : .gray)
                    .frame(width: 12, height: 12)

                Text(isOnCourt ? "ON COURT" : "OFF COURT")
                    .font(.headline)
                    .foregroundStyle(isOnCourt ? .green : .secondary)

                Spacer()

                if isOnCourt {
                    // Current shift timer
                    Text(shiftDuration)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.blue)
                }
            }

            // Shift toggle button
            Button {
                if isOnCourt {
                    // Pre-populate with starting scores (user adjusts to current)
                    teamScore = currentShift?.startingTeamScore ?? 0
                    opponentScore = currentShift?.startingOpponentScore ?? 0
                    showingEndShiftSheet = true
                } else {
                    // Pre-populate with last known scores from previous shift
                    teamScore = lastKnownTeamScore
                    opponentScore = lastKnownOpponentScore

                    // Check if player has multiple positions that need confirmation
                    if hasMultiplePositions {
                        showingPositionConfirmation = true
                    } else {
                        showingStartShiftSheet = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isOnCourt ? "stop.fill" : "play.fill")
                    Text(isOnCourt ? "End Shift" : "Start Shift")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isOnCourt ? .red : .green)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Shift count and total time
            HStack {
                Label("\(personGameStats.completedShifts.count) shifts", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                Spacer()
                Label(personGameStats.formattedTotalShiftTime, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Active Shift Stats View

    @ViewBuilder
    private var shiftStatsView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Points display
                HStack {
                    Text("\(currentShift?.totalPoints ?? 0)")
                        .scaledFont(size: 48, weight: .bold, relativeTo: .largeTitle)
                        .foregroundStyle(.blue)
                    Text("PTS this shift")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                // Shooting buttons
                HStack(spacing: 10) {
                    ShiftStatButton(title: "2 PTS", subtitle: shiftMadeString("2PT"), color: .blue, action: { recordShiftMade("2PT", points: 2) }, undoAction: { undoShiftMade("2PT") })
                    ShiftStatButton(title: "3 PTS", subtitle: shiftMadeString("3PT"), color: .purple, action: { recordShiftMade("3PT", points: 3) }, undoAction: { undoShiftMade("3PT") })
                    ShiftStatButton(title: "FT", subtitle: shiftMadeString("FT"), color: .orange, action: { recordShiftMade("FT", points: 1) }, undoAction: { undoShiftMade("FT") })
                }
                .padding(.horizontal)

                // Miss buttons
                HStack(spacing: 8) {
                    MissButton(title: "2PT Miss", action: { recordShiftMiss("2PT", points: 2) }, undoAction: { undoShiftMiss("2PT") })
                    MissButton(title: "3PT Miss", action: { recordShiftMiss("3PT", points: 3) }, undoAction: { undoShiftMiss("3PT") })
                    MissButton(title: "FT Miss", action: { recordShiftMiss("FT", points: 1) }, undoAction: { undoShiftMiss("FT") })
                }
                .padding(.horizontal)

                // Other stats
                HStack(spacing: 10) {
                    ShiftStatButton(title: "D-REB", subtitle: shiftCountString("DREB"), color: .green, action: { recordShiftCount("DREB") }, undoAction: { undoShiftCount("DREB") })
                    ShiftStatButton(title: "O-REB", subtitle: shiftCountString("OREB"), color: .teal, action: { recordShiftCount("OREB") }, undoAction: { undoShiftCount("OREB") })
                    ShiftStatButton(title: "STEAL", subtitle: shiftCountString("STL"), color: .indigo, action: { recordShiftCount("STL") }, undoAction: { undoShiftCount("STL") })
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
                    ShiftStatButton(title: "ASSIST", subtitle: shiftCountString("AST"), color: .mint, action: { recordShiftCount("AST") }, undoAction: { undoShiftCount("AST") })
                    ShiftStatButton(title: "FOUL", subtitle: shiftCountString("PF"), color: .red, action: { recordShiftCount("PF") }, undoAction: { undoShiftCount("PF") })
                    ShiftStatButton(title: "TURNOVER", subtitle: shiftCountString("TO"), color: .brown, action: { recordShiftCount("TO") }, undoAction: { undoShiftCount("TO") })
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
                    ShiftStatButton(title: "MISSED DRIVE", subtitle: shiftCountString("MD"), color: .orange, action: { recordShiftCount("MD") }, undoAction: { undoShiftCount("MD") })
                    ShiftStatButton(title: "BAD OFF", subtitle: shiftCountString("BPO"), color: .red, action: { recordShiftCount("BPO") }, undoAction: { undoShiftCount("BPO") })
                    ShiftStatButton(title: "BAD DEF", subtitle: shiftCountString("BPD"), color: .pink, action: { recordShiftCount("BPD") }, undoAction: { undoShiftCount("BPD") })
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
                    ShiftStatButton(title: "SUCCESS DRIVE", subtitle: shiftCountString("SD"), color: .green, action: { recordShiftCount("SD") }, undoAction: { undoShiftCount("SD") })
                    ShiftStatButton(title: "GREAT OFF", subtitle: shiftCountString("GPO"), color: .yellow, action: { recordShiftCount("GPO") }, undoAction: { undoShiftCount("GPO") })
                    ShiftStatButton(title: "GREAT DEF", subtitle: shiftCountString("GPD"), color: .green, action: { recordShiftCount("GPD") }, undoAction: { undoShiftCount("GPD") })
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Off Court View

    @ViewBuilder
    private var offCourtView: some View {
        if personGameStats.completedShifts.isEmpty {
            ContentUnavailableView {
                Label("No Shifts Yet", systemImage: "figure.run")
            } description: {
                Text("Tap 'Start Shift' when the player enters the game")
            }
        } else {
            // Show completed shifts summary
            List {
                Section("Completed Shifts") {
                    ForEach(personGameStats.completedShifts) { shift in
                        ShiftSummaryRow(shift: shift)
                    }
                }

                Section("Game Totals") {
                    LabeledContent("Total Points", value: "\(personGameStats.totalPoints)")
                    LabeledContent("Total Time", value: personGameStats.formattedTotalShiftTime)
                    LabeledContent("Shifts", value: "\(personGameStats.completedShifts.count)")

                    HStack {
                        Text("Plus/Minus")
                        Spacer()
                        Text(personGameStats.formattedTotalPlusMinus)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                personGameStats.totalPlusMinus > 0 ? .green :
                                personGameStats.totalPlusMinus < 0 ? .red : .secondary
                            )
                    }
                }
            }
        }
    }

    // MARK: - Shift Management

    private func startNewShift() {
        let shift = personGameStats.startNewShift(
            teamScore: teamScore,
            opponentScore: opponentScore,
            position: selectedShiftPosition ?? playerPositionAssignments.primaryPosition
        )
        modelContext.insert(shift)
        saveOrSurfaceError()
    }

    private func endCurrentShift() {
        personGameStats.endCurrentShift(
            teamScore: teamScore,
            opponentScore: opponentScore
        )
        saveOrSurfaceError()
    }

    // MARK: - Shift Stat Recording

    private func recordShiftMade(_ name: String, points: Int) {
        recordShiftStat(name, points: points, mutation: .made)
    }

    private func recordShiftMiss(_ name: String, points: Int) {
        recordShiftStat(name, points: points, mutation: .missed)
    }

    private func recordShiftCount(_ name: String) {
        recordShiftStat(name, points: 0, mutation: .count)
    }

    private func recordShiftStat(_ name: String, points: Int, mutation: StatMutation) {
        guard let shift = currentShift,
              let game = personGameStats.game else { return }
        do {
            try game.recordStat(
                named: name,
                pointValue: points,
                mutation: mutation,
                personGameStats: personGameStats,
                shift: shift,
                in: modelContext
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    private func undoShiftMade(_ name: String) {
        undoShiftStat(name, mutation: .made)
    }

    private func undoShiftMiss(_ name: String) {
        undoShiftStat(name, mutation: .missed)
    }

    private func undoShiftCount(_ name: String) {
        undoShiftStat(name, mutation: .count)
    }

    private func undoShiftStat(_ name: String, mutation: StatMutation) {
        guard let shift = currentShift,
              let game = personGameStats.game else { return }
        do {
            guard try game.undoStat(
                named: name,
                mutation: mutation,
                personGameStats: personGameStats,
                shift: shift
            ) else { return }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    private func saveOrSurfaceError() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    // MARK: - Display Helpers

    private func shiftMadeString(_ name: String) -> String {
        currentShift?.madeString(forName: name) ?? "0/0"
    }

    private func shiftCountString(_ name: String) -> String {
        "\(currentShift?.totalCount(forName: name) ?? 0)"
    }
}

// MARK: - Components


#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersonGameStats.self, Game.self, Stat.self, Shift.self, ShiftStat.self, configurations: config)

    let pgs = PersonGameStats()
    container.mainContext.insert(pgs)

    return ShiftTrackingView(personGameStats: pgs)
        .modelContainer(container)
}

private struct ShiftStatButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    var undoAction: (() -> Void)? = nil

    var body: some View {
        RecordingStatButton(title: title, subtitle: subtitle, color: color, action: action, undoAction: undoAction)
            .frame(height: 70)
    }
}
