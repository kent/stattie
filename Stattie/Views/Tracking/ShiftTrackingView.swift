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

    // Score tracking
    @State private var teamScore: Int = 0
    @State private var opponentScore: Int = 0

    // Last known scores (to auto-populate for next shift)
    private var lastKnownTeamScore: Int {
        personGameStats.completedShifts.last?.endingTeamScore ?? 0
    }
    private var lastKnownOpponentScore: Int {
        personGameStats.completedShifts.last?.endingOpponentScore ?? 0
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
                    onStart: {
                        startNewShift()
                    }
                )
                .presentationDetents([.medium])
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
            .sheet(isPresented: $showingPositionConfirmation) {
                PositionConfirmationSheet(
                    positionAssignments: playerPositionAssignments,
                    playerName: personGameStats.person?.displayName ?? "Player",
                    selectedPosition: $selectedShiftPosition,
                    onConfirm: {
                        showingPositionConfirmation = false
                        showingStartShiftSheet = true
                    }
                )
                .presentationDetents([.medium])
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
                        .font(.system(size: 48, weight: .bold))
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
                    ShiftStatButton(title: "MISSED DRIVE", subtitle: shiftCountString("MD"), color: .orange, action: { recordShiftCount("MD") }, undoAction: { undoShiftCount("MD") })
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
                    ShiftStatButton(title: "BAD OFF", subtitle: shiftCountString("BPO"), color: .red, action: { recordShiftCount("BPO") }, undoAction: { undoShiftCount("BPO") })
                    ShiftStatButton(title: "BAD DEF", subtitle: shiftCountString("BPD"), color: .pink, action: { recordShiftCount("BPD") }, undoAction: { undoShiftCount("BPD") })
                    ShiftStatButton(title: "SUCCESS DRIVE", subtitle: shiftCountString("SD"), color: .green, action: { recordShiftCount("SD") }, undoAction: { undoShiftCount("SD") })
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
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
            opponentScore: opponentScore
        )
        modelContext.insert(shift)
        try? modelContext.save()
    }

    private func endCurrentShift() {
        personGameStats.endCurrentShift(
            teamScore: teamScore,
            opponentScore: opponentScore
        )
        try? modelContext.save()
    }

    // MARK: - Shift Stat Recording

    private func getOrCreateShiftStat(_ name: String, points: Int) -> ShiftStat {
        guard let shift = currentShift else {
            fatalError("No active shift")
        }

        if let existing = shift.statValue(forName: name) {
            return existing
        }

        let stat = ShiftStat(statName: name, pointValue: points, shift: shift)
        modelContext.insert(stat)

        if shift.stats == nil { shift.stats = [] }
        shift.stats?.append(stat)

        return stat
    }

    private func recordShiftMade(_ name: String, points: Int) {
        guard currentShift != nil else { return }
        let stat = getOrCreateShiftStat(name, points: points)
        stat.made += 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func recordShiftMiss(_ name: String, points: Int) {
        guard currentShift != nil else { return }
        let stat = getOrCreateShiftStat(name, points: points)
        stat.missed += 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func recordShiftCount(_ name: String) {
        guard currentShift != nil else { return }
        let stat = getOrCreateShiftStat(name, points: 0)
        stat.count += 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func undoShiftMade(_ name: String) {
        guard let shift = currentShift,
              let stat = shift.statValue(forName: name),
              stat.made > 0 else { return }
        stat.made -= 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func undoShiftMiss(_ name: String) {
        guard let shift = currentShift,
              let stat = shift.statValue(forName: name),
              stat.missed > 0 else { return }
        stat.missed -= 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func undoShiftCount(_ name: String) {
        guard let shift = currentShift,
              let stat = shift.statValue(forName: name),
              stat.count > 0 else { return }
        stat.count -= 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    // MARK: - Display Helpers

    private func shiftMadeString(_ name: String) -> String {
        guard let shift = currentShift,
              let stat = shift.statValue(forName: name) else {
            return "0/0"
        }
        return "\(stat.made)/\(stat.made + stat.missed)"
    }

    private func shiftCountString(_ name: String) -> String {
        guard let shift = currentShift,
              let stat = shift.statValue(forName: name) else {
            return "0"
        }
        return "\(stat.count)"
    }
}

// MARK: - Components

struct ShiftStatButton: View {
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
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: action)
        .onLongPressGesture(minimumDuration: 0.45) {
            undoAction?()
        }
        .accessibilityHint(undoAction == nil ? "Double tap to record" : "Double tap to record. Long press to undo one.")
        .accessibilityAddTraits(.isButton)
    }
}

struct ShiftSummaryRow: View {
    let shift: Shift

    private var plusMinusColor: Color {
        guard let pm = shift.plusMinus else { return .secondary }
        if pm > 0 { return .green }
        if pm < 0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shift \(shift.shiftNumber)")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(shift.formattedDuration)
                    if shift.plusMinus != nil {
                        Text("•")
                        Text("\(shift.startingTeamScore)-\(shift.startingOpponentScore) → \(shift.endingTeamScore ?? 0)-\(shift.endingOpponentScore ?? 0)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(shift.totalPoints) pts")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Text(shift.formattedPlusMinus)
                    .font(.subheadline.bold())
                    .foregroundStyle(plusMinusColor)
            }
        }
    }
}

// MARK: - Score Input Sheets

struct StartShiftScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var teamScore: Int
    @Binding var opponentScore: Int
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter Current Score")
                    .font(.headline)
                    .padding(.top)

                Text("What's the score when entering the game?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Pre-filled from the previous shift. Type to adjust quickly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScoreInputPairView(teamScore: $teamScore, opponentScore: $opponentScore)
                    .padding(.horizontal)

                Spacer()

                Button {
                    onStart()
                    dismiss()
                } label: {
                    Text("Start Shift")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Start Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
        }
    }
}

struct EndShiftScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var teamScore: Int
    @Binding var opponentScore: Int
    let startingTeamScore: Int
    let startingOpponentScore: Int
    let onEnd: () -> Void

    private var plusMinus: Int {
        let teamDiff = teamScore - startingTeamScore
        let oppDiff = opponentScore - startingOpponentScore
        return teamDiff - oppDiff
    }

    private var plusMinusText: String {
        if plusMinus > 0 { return "+\(plusMinus)" }
        return "\(plusMinus)"
    }

    private var plusMinusColor: Color {
        if plusMinus > 0 { return .green }
        if plusMinus < 0 { return .red }
        return .secondary
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter Current Score")
                    .font(.headline)
                    .padding(.top)

                Text("What's the score when leaving the game?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Type scores directly for larger totals, or use quick buttons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Starting score reference
                HStack {
                    Text("Started at:")
                        .foregroundStyle(.secondary)
                    Text("\(startingTeamScore) - \(startingOpponentScore)")
                        .font(.headline)
                }
                .font(.subheadline)

                ScoreInputPairView(teamScore: $teamScore, opponentScore: $opponentScore)
                    .padding(.horizontal)

                // Plus/Minus preview
                VStack(spacing: 4) {
                    Text("Plus/Minus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(plusMinusText)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(plusMinusColor)
                }

                Spacer()

                Button {
                    onEnd()
                    dismiss()
                } label: {
                    Text("End Shift")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("End Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
        }
    }
}

struct ScoreInputPairView: View {
    @Binding var teamScore: Int
    @Binding var opponentScore: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                ScoreInputColumn(title: "Our Team", score: $teamScore, color: .blue)
                    .frame(maxWidth: .infinity)
                ScoreInputColumn(title: "Opponent", score: $opponentScore, color: .red)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 16) {
                ScoreInputColumn(title: "Our Team", score: $teamScore, color: .blue)
                ScoreInputColumn(title: "Opponent", score: $opponentScore, color: .red)
            }
        }
    }
}

struct ScoreInputColumn: View {
    let title: String
    @Binding var score: Int
    let color: Color

    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    if score > 0 {
                        score -= 1
                        impactLight.impactOccurred()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(color.opacity(0.7))
                }

                TextField("0", value: $score, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .frame(minWidth: 64, idealWidth: 78, maxWidth: 96)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: score) { _, newValue in
                        if newValue < 0 {
                            score = 0
                        }
                    }

                Button {
                    score += 1
                    impactLight.impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(color)
                }
            }

            // Quick increment buttons for basketball scoring
            HStack(spacing: 8) {
                QuickScoreButton(label: "+2", color: color) {
                    score += 2
                    impactLight.impactOccurred()
                }
                QuickScoreButton(label: "+3", color: color) {
                    score += 3
                    impactLight.impactOccurred()
                }
            }
        }
    }
}

struct QuickScoreButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Position Confirmation Sheet

struct PositionConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let positionAssignments: PositionAssignments
    let playerName: String
    @Binding var selectedPosition: SoccerPosition?
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Which position?")
                        .font(.title2.bold())

                    Text("\(playerName) has multiple positions. Select the position for this shift.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Position options
                VStack(spacing: 12) {
                    ForEach(positionAssignments.assignments) { assignment in
                        Button {
                            selectedPosition = assignment.position
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(selectedPosition == assignment.position ?
                                              Color.accentColor : Color(.systemGray5))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: assignment.position.iconName)
                                        .font(.title3)
                                        .foregroundStyle(selectedPosition == assignment.position ?
                                                        .white : .primary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(assignment.position.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("\(assignment.percentage)% of play time")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedPosition == assignment.position {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.accent)
                                }
                            }
                            .padding()
                            .background(
                                selectedPosition == assignment.position ?
                                Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedPosition == assignment.position ?
                                           Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Confirm button
                Button {
                    onConfirm()
                } label: {
                    Text("Start Shift as \(selectedPosition?.displayName ?? "Selected Position")")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedPosition != nil ? Color.green : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedPosition == nil)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Select Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Default to primary position
                if selectedPosition == nil {
                    selectedPosition = positionAssignments.primaryPosition
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersonGameStats.self, Shift.self, ShiftStat.self, configurations: config)

    let pgs = PersonGameStats()
    container.mainContext.insert(pgs)

    return ShiftTrackingView(personGameStats: pgs)
        .modelContainer(container)
}
