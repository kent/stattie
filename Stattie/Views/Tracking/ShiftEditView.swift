import SwiftUI
import SwiftData

struct ShiftEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var shift: Shift
    let playerName: String
    @State private var editableDurationSeconds: Int = 0
    @State private var persistenceError: String?

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
        CountStatConfig(name: "TO", title: "Turnovers"),
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
                if let sportName = shift.personGameStats?.game?.sport?.name {
                    Picker("Position", selection: shiftPositionBinding) {
                        Text("Unspecified").tag(Optional<SoccerPosition>.none)
                        ForEach(SoccerPosition.positions(for: SoccerPosition.supportedSport(for: sportName))) { position in
                            Text(position.displayName).tag(Optional(position))
                        }
                    }
                } else if let position = shift.recordedPosition {
                    LabeledContent("Position", value: position.displayName)
                }
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
                    if save() {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            editableDurationSeconds = max(0, Int(shift.duration.rounded()))
        }
        .alert(
            "Couldn’t Save Changes",
            isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "The shift changes could not be saved.")
        }
    }

    private var plusMinusColor: Color {
        guard let plusMinus = shift.plusMinus else { return .secondary }
        if plusMinus > 0 { return .green }
        if plusMinus < 0 { return .red }
        return .secondary
    }

    private var shiftPositionBinding: Binding<SoccerPosition?> {
        Binding(
            get: { shift.recordedPosition },
            set: { newValue in
                shift.recordedPosition = newValue
                save()
            }
        )
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

    private func getOrCreateShiftStat(name: String, points: Int) -> Stat {
        if let existing = shift.statValue(forName: name) {
            return existing
        }

        guard let personGameStats = shift.personGameStats,
              let game = personGameStats.game else {
            preconditionFailure("A shift must belong to player game stats before editing")
        }
        let stat = Stat(
            statName: name,
            pointValue: points,
            personGameStats: personGameStats,
            game: game,
            shift: shift
        )
        modelContext.insert(stat)
        if shift.statRecords == nil { shift.statRecords = [] }
        shift.statRecords?.append(stat)
        if personGameStats.stats == nil { personGameStats.stats = [] }
        personGameStats.stats?.append(stat)
        if game.stats == nil { game.stats = [] }
        game.stats?.append(stat)
        return stat
    }

    private func cleanupShiftStatIfEmpty(_ stat: Stat) {
        guard stat.isEmpty else { return }
        shift.statRecords?.removeAll { $0.id == stat.id }
        shift.personGameStats?.stats?.removeAll { $0.id == stat.id }
        shift.personGameStats?.game?.stats?.removeAll { $0.id == stat.id }
        modelContext.delete(stat)
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
            return false
        }
    }
}

#Preview {
    GameTrackingView(game: Game(opponent: "Lakers"))
        .modelContainer(for: [Game.self, Stat.self, Person.self, PersonGameStats.self, Shift.self], inMemory: true)
}
