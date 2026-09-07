import SwiftUI
import SwiftData

struct PlayerGameOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var persistence = PersistenceController()

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

    private var usesShiftTracking: Bool {
        game?.sport?.usesShiftTracking ?? true
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
        guard usesShiftTracking else {
            return game?.sport?.name ?? "Individual sport"
        }
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

        if game?.sport?.isTeamSport == false || SportCatalog.profile(named: game?.sport?.name)?.usesCustomTracking == false {
            return (game?.sport?.sortedStatDefinitions ?? []).prefix(8).map { definition in
                if definition.hasMadeAndMissed {
                    let made = personGameStats.aggregatedMade(forName: definition.shortName)
                    let missed = personGameStats.aggregatedMissed(forName: definition.shortName)
                    return OverviewMetric(
                        id: definition.shortName,
                        title: definition.name,
                        value: "\(made)/\(made + missed)"
                    )
                }
                return OverviewMetric(
                    id: definition.shortName,
                    title: definition.name,
                    value: "\(personGameStats.aggregatedCount(forName: definition.shortName))"
                )
            }
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
                if usesShiftTracking {
                    currentShiftSection
                    shiftsSection
                }
                totalsSection
                positionBreakdownSection
                snapshotSection
            }
            .persistenceAlert(persistence)
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
                    guard let game else { return }
                    persistence.save(modelContext) {
                        _ = try game.finalize(in: modelContext)
                    }
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
                } else if let sportName = game?.sport?.name, !sportName.isEmpty {
                    Text(sportName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let teamName = game?.team?.name, !teamName.isEmpty {
                    Text(teamName)
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
    private var positionBreakdownSection: some View {
        let totals = PositionStatAggregator.totals(from: personGameStats.shifts ?? [])
            .filter { $0.position != nil }
        if !totals.isEmpty {
            Section("By Position") {
                ForEach(totals) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(item.displayName, systemImage: item.iconName)
                            Spacer()
                            Text("\(item.shiftCount) \(item.shiftCount == 1 ? "shift" : "shifts")")
                                .foregroundStyle(.secondary)
                        }
                        Text("\(item.formattedDuration)  •  \(item.formattedPlusMinus)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(PositionStatAggregator.highlightLines(for: item, sportName: game?.sport?.name).enumerated()), id: \.offset) { _, line in
                            LabeledContent(line.title, value: line.value)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var totalsSection: some View {
        Section("Totals") {
            if usesShiftTracking {
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
            } else if let definition = game?.sport?.sortedStatDefinitions.first {
                LabeledContent(
                    definition.name,
                    value: definition.hasMadeAndMissed
                        ? "\(personGameStats.aggregatedMade(forName: definition.shortName))"
                        : "\(personGameStats.aggregatedCount(forName: definition.shortName))"
                )
            }
        }
    }

    @ViewBuilder
    private var snapshotSection: some View {
        Section(snapshotSectionTitle) {
            ForEach(snapshotMetrics) { metric in
                LabeledContent(metric.title, value: metric.value)
            }
        }
    }

    private var snapshotSectionTitle: String {
        if isSoccer { return "Soccer Snapshot" }
        if game?.sport?.name == "Basketball" { return "Basketball Snapshot" }
        return "\(game?.sport?.name ?? "Game") Snapshot"
    }

    @ViewBuilder
    private func actionBar() -> some View {
        if !(game?.isCompleted ?? false) {
            VStack(spacing: 10) {
                Button {
                    openTracker()
                } label: {
                    Label(trackingActionTitle, systemImage: trackingActionIcon)
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

    private var trackingActionTitle: String {
        if usesShiftTracking {
            return hasActiveShift ? "Continue Shift Tracking" : "Start New Shift"
        }
        return "Track Stats"
    }

    private var trackingActionIcon: String {
        if usesShiftTracking {
            return hasActiveShift ? "waveform.path.ecg" : "play.fill"
        }
        return "chart.bar.fill"
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

        let previousShifts = personGameStats.shifts
        let previousNumbers = (previousShifts ?? []).map { ($0, $0.shiftNumber) }
        personGameStats.shifts?.removeAll { $0.id == shift.id }
        modelContext.delete(shift)
        normalizeShiftNumbers()
        persistence.save(modelContext, restoring: {
            personGameStats.shifts = previousShifts
            for (shift, number) in previousNumbers { shift.shiftNumber = number }
        })
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
