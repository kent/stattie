import SwiftUI
import SwiftData

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
                    if let position = shift.recordedPosition {
                        Label(position.shortName, systemImage: position.iconName)
                    }
                    Text(shift.formattedDuration)
                    if shift.plusMinus != nil {
                        let endingTeam = shift.endingTeamScore ?? shift.startingTeamScore
                        let endingOpponent = shift.endingOpponentScore ?? shift.startingOpponentScore
                        Text("•")
                        Text("\(shift.startingTeamScore)-\(shift.startingOpponentScore) → \(endingTeam)-\(endingOpponent)")
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
    var sportName: String? = nil
    var assignedPositions: [SoccerPosition] = []
    @Binding var selectedPosition: SoccerPosition?
    let onStart: () -> Void

    @State private var showingPositionPicker = false

    private var resolvedPosition: SoccerPosition? {
        selectedPosition
    }

    private var hasPositionChoices: Bool {
        !SoccerPosition.positions(for: SoccerPosition.supportedSport(for: sportName)).isEmpty
    }

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

                if hasPositionChoices {
                    Button {
                        showingPositionPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: resolvedPosition?.iconName ?? "figure.run")
                                .font(.title3)
                                .foregroundStyle(.accent)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Position this shift")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(resolvedPosition?.displayName ?? "Choose a position")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .accessibilityLabel("Position this shift")
                    .accessibilityValue(resolvedPosition?.displayName ?? "None selected")
                    .accessibilityHint("Double tap to choose a different position")
                }

                ScoreInputPairView(teamScore: $teamScore, opponentScore: $opponentScore)
                    .padding(.horizontal)

                Spacer()

                Button {
                    onStart()
                    dismiss()
                } label: {
                    Text(resolvedPosition.map { "Start Shift as \($0.displayName)" } ?? "Start Shift")
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
            .sheet(isPresented: $showingPositionPicker) {
                ShiftPositionPickerSheet(
                    sportName: sportName,
                    assignedPositions: assignedPositions,
                    playerName: "This shift",
                    confirmTitle: "Use Position",
                    selectedPosition: $selectedPosition
                )
            }
            .onAppear {
                if selectedPosition == nil {
                    selectedPosition = assignedPositions.first
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
                        .scaledFont(size: 48, weight: .bold, relativeTo: .largeTitle)
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
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
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

