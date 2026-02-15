import SwiftUI
import SwiftData

/// View for tracking stats per shift for a person in a game
struct ShiftTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var personGameStats: PersonGameStats
    @State private var showingEndShiftAlert = false

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
            .alert("End Shift?", isPresented: $showingEndShiftAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Shift") {
                    endCurrentShift()
                }
            } message: {
                Text("End current shift and record stats?")
            }
        }
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
                    showingEndShiftAlert = true
                } else {
                    startNewShift()
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
                    ShiftStatButton(title: "2 PTS", subtitle: shiftMadeString("2PT"), color: .blue) {
                        recordShiftMade("2PT", points: 2)
                    }
                    ShiftStatButton(title: "3 PTS", subtitle: shiftMadeString("3PT"), color: .purple) {
                        recordShiftMade("3PT", points: 3)
                    }
                    ShiftStatButton(title: "FT", subtitle: shiftMadeString("FT"), color: .orange) {
                        recordShiftMade("FT", points: 1)
                    }
                }
                .padding(.horizontal)

                // Miss buttons
                HStack(spacing: 8) {
                    MissButton(title: "2PT Miss") { recordShiftMiss("2PT", points: 2) }
                    MissButton(title: "3PT Miss") { recordShiftMiss("3PT", points: 3) }
                    MissButton(title: "FT Miss") { recordShiftMiss("FT", points: 1) }
                }
                .padding(.horizontal)

                // Other stats
                HStack(spacing: 10) {
                    ShiftStatButton(title: "D-REB", subtitle: shiftCountString("DREB"), color: .green) {
                        recordShiftCount("DREB")
                    }
                    ShiftStatButton(title: "O-REB", subtitle: shiftCountString("OREB"), color: .teal) {
                        recordShiftCount("OREB")
                    }
                    ShiftStatButton(title: "STEAL", subtitle: shiftCountString("STL"), color: .indigo) {
                        recordShiftCount("STL")
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 10) {
                    ShiftStatButton(title: "ASSIST", subtitle: shiftCountString("AST"), color: .mint) {
                        recordShiftCount("AST")
                    }
                    ShiftStatButton(title: "DRIVE", subtitle: shiftCountString("DRV"), color: .cyan) {
                        recordShiftCount("DRV")
                    }
                    ShiftStatButton(title: "FOUL", subtitle: shiftCountString("PF"), color: .red) {
                        recordShiftCount("PF")
                    }
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
                }
            }
        }
    }

    // MARK: - Shift Management

    private func startNewShift() {
        let shift = personGameStats.startNewShift()
        modelContext.insert(shift)
        try? modelContext.save()
    }

    private func endCurrentShift() {
        personGameStats.endCurrentShift()
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

    var body: some View {
        Button(action: action) {
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
        }
    }
}

struct ShiftSummaryRow: View {
    let shift: Shift

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shift \(shift.shiftNumber)")
                    .font(.headline)
                Text(shift.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(shift.totalPoints) pts")
                .font(.headline)
                .foregroundStyle(.blue)
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
