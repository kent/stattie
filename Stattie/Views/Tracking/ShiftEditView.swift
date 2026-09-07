import SwiftUI
import SwiftData

struct ShiftEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let shift: Shift
    let playerName: String
    @State private var draft: ShiftEditDraft
    @State private var persistenceError: String?

    init(shift: Shift, playerName: String) {
        self.shift = shift
        self.playerName = playerName
        _draft = State(initialValue: ShiftEditDraft(shift: shift))
    }

    private var positions: [SoccerPosition] {
        SoccerPosition.positions(for: SoccerPosition.supportedSport(for: shift.personGameStats?.game?.sport?.name))
    }

    private var durationSeconds: Int {
        guard let end = draft.details.endTime else { return 0 }
        return max(0, Int(end.timeIntervalSince(draft.details.startTime).rounded()))
    }

    private var plusMinusText: String {
        guard let value = draft.details.plusMinus else { return "--" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Player", value: playerName)
                Picker("Position", selection: $draft.details.positionRawValue) {
                    Text("Unspecified").tag("")
                    ForEach(positions) { position in
                        Text(position.displayName).tag(position.rawValue)
                    }
                    if !draft.details.positionRawValue.isEmpty,
                       !positions.contains(where: { $0.rawValue == draft.details.positionRawValue }) {
                        Text(shift.recordedPosition?.displayName ?? draft.details.positionRawValue)
                            .tag(draft.details.positionRawValue)
                    }
                }
            }

            Section {
                DatePicker("Started", selection: $draft.details.startTime, displayedComponents: [.date, .hourAndMinute])
                if draft.details.endTime != nil {
                    DatePicker("Ended", selection: endingTime, displayedComponents: [.date, .hourAndMinute])
                    ShiftNumberField(title: "Duration minutes", value: durationComponent(isMinutes: true))
                    ShiftNumberField(title: "Duration seconds", value: durationComponent(isMinutes: false))
                } else {
                    Text("This shift is still in progress.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Time Played")
            } footer: {
                Text("Correct the start and end times, or enter the exact duration.")
            }

            Section {
                ShiftNumberField(title: "Start team", value: $draft.details.startingTeamScore)
                ShiftNumberField(title: "Start opponent", value: $draft.details.startingOpponentScore)
                if draft.details.endTime != nil {
                    Toggle("Ending score recorded", isOn: hasEndingScore)
                    if hasEndingScore.wrappedValue {
                        ShiftNumberField(title: "End team", value: endingScore(isTeam: true))
                        ShiftNumberField(title: "End opponent", value: endingScore(isTeam: false))
                    }
                }
                LabeledContent("Plus/minus", value: plusMinusText)
            } header: {
                Text("Score")
            } footer: {
                Text("Scores apply to this shift. Review adjacent shifts and the final game score when reconciling.")
            }

            Section {
                ForEach($draft.stats) { $stat in
                    if stat.hasMadeAndMissed || stat.values.made > 0 || stat.values.missed > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(stat.title).font(.headline)
                            ShiftNumberField(title: "Made", value: $stat.values.made)
                            ShiftNumberField(title: "Missed", value: $stat.values.missed)
                            if stat.values.count > 0 {
                                ShiftNumberField(title: "Count", value: $stat.values.count)
                            }
                        }
                    } else {
                        ShiftNumberField(title: stat.title, value: $stat.values.count)
                    }
                }
            } header: {
                Text("Stats")
            } footer: {
                Text("Changes update this shift, the player's game totals, and position breakdowns when saved.")
            }
        }
        .navigationTitle("Edit Shift \(shift.shiftNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .errorAlert(title: "Couldn’t Save Shift", message: $persistenceError)
    }

    private var endingTime: Binding<Date> {
        Binding(get: { draft.details.endTime ?? draft.details.startTime }, set: { draft.details.endTime = $0 })
    }

    private func durationComponent(isMinutes: Bool) -> Binding<Int> {
        Binding(
            get: { isMinutes ? durationSeconds / 60 : durationSeconds % 60 },
            set: { value in
                let seconds = isMinutes ? max(0, value) * 60 + durationSeconds % 60 : durationSeconds / 60 * 60 + max(0, value)
                draft.details.endTime = draft.details.startTime.addingTimeInterval(TimeInterval(seconds))
            }
        )
    }

    private var hasEndingScore: Binding<Bool> {
        Binding(
            get: { draft.details.endingTeamScore != nil || draft.details.endingOpponentScore != nil },
            set: { recorded in
                draft.details.endingTeamScore = recorded ? draft.details.startingTeamScore : nil
                draft.details.endingOpponentScore = recorded ? draft.details.startingOpponentScore : nil
            }
        )
    }

    private func endingScore(isTeam: Bool) -> Binding<Int> {
        Binding(
            get: { isTeam ? draft.details.endingTeamScore ?? 0 : draft.details.endingOpponentScore ?? 0 },
            set: { if isTeam { draft.details.endingTeamScore = $0 } else { draft.details.endingOpponentScore = $0 } }
        )
    }

    private func save() {
        do {
            try draft.save(to: shift, in: modelContext)
            dismiss()
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}

private struct ShiftNumberField: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: Binding(get: { value }, set: { value = min(1_000_000, max(0, $0)) }), format: .number.grouping(.never))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 60, maxWidth: 110)
                .accessibilityLabel(title)
        }
    }
}
