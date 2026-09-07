import SwiftUI
import SwiftData

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
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let undoAction {
                Button("Undo \(title)", systemImage: "arrow.uturn.backward", action: undoAction)
            }
        }
        .accessibilityLabel("Record \(title)")
        .accessibilityHint(undoAction == nil ? "Double tap to record a miss" : "Double tap to record. Use the context menu to undo one.")
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

    private var isBasketball: Bool {
        game.sport?.name == "Basketball"
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

        if isBasketball {
            return [
                SummaryMetric(title: "Points", value: "\(shift.totalPoints)", icon: "basketball.fill", tint: .blue),
                SummaryMetric(title: "Rebounds", value: "\(shift.totalCount(forName: "DREB") + shift.totalCount(forName: "OREB"))", icon: "arrow.up.circle.fill", tint: .green),
                SummaryMetric(title: "Assists", value: "\(shift.totalCount(forName: "AST"))", icon: "arrow.triangle.branch", tint: .mint),
                SummaryMetric(title: "Steals", value: "\(shift.totalCount(forName: "STL"))", icon: "hand.raised.fill", tint: .indigo),
                SummaryMetric(title: "Fouls", value: "\(shift.totalCount(forName: "PF"))", icon: "exclamationmark.triangle.fill", tint: .red),
                SummaryMetric(title: "Turnovers", value: "\(shift.totalCount(forName: "TO"))", icon: "arrow.uturn.backward.circle.fill", tint: .brown),
                SummaryMetric(title: "Missed Drive", value: "\(shift.totalCount(forName: "MD"))", icon: "xmark.circle.fill", tint: .orange),
                SummaryMetric(title: "Successful Drive", value: "\(shift.totalCount(forName: "SD"))", icon: "checkmark.circle.fill", tint: .green),
            ]
        }

        return (game.sport?.sortedStatDefinitions ?? []).prefix(8).map { definition in
            let value: String
            if definition.hasMadeAndMissed {
                let made = shift.totalMade(forName: definition.shortName)
                let missed = shift.totalMissed(forName: definition.shortName)
                value = "\(made)/\(made + missed)"
            } else {
                value = "\(shift.totalCount(forName: definition.shortName))"
            }
            return SummaryMetric(
                title: definition.name,
                value: value,
                icon: definition.iconName.isEmpty ? "sportscourt" : definition.iconName,
                tint: .accentColor
            )
        }
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
                        if let position = shift.recordedPosition {
                            Label(position.displayName, systemImage: position.iconName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
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

                    Text(isSoccer ? "Soccer Snapshot" : isBasketball ? "Basketball Snapshot" : "\(game.sport?.name ?? "Game") Snapshot")
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
                        NavigationLink {
                            ShiftEditView(shift: activeShift, playerName: playerName)
                        } label: {
                            ShiftSummaryRow(shift: activeShift)
                        }
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
