import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var game: Game

    @State private var showingSummary = false
    @State private var showingTracking = false

    var sortedPersonStats: [PersonGameStats] {
        (game.personStats ?? []).sorted {
            ($0.person?.jerseyNumber ?? 0) < ($1.person?.jerseyNumber ?? 0)
        }
    }

    private var isSoccer: Bool {
        game.sport?.name == "Soccer"
    }

    var body: some View {
        List {
            // Score header
            Section {
                VStack(spacing: 12) {
                    Text("\(game.totalPoints)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.accent)

                    Text(isSoccer ? "Goals" : "Total Points")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Quick stats row
                    if !isSoccer {
                        HStack(spacing: 24) {
                            QuickStatPill(value: game.stat(named: "DREB")?.count ?? 0 + (game.stat(named: "OREB")?.count ?? 0), label: "REB")
                            QuickStatPill(value: game.stat(named: "AST")?.count ?? 0, label: "AST")
                            QuickStatPill(value: game.stat(named: "STL")?.count ?? 0, label: "STL")
                        }
                        .padding(.top, 8)
                    } else {
                        HStack(spacing: 24) {
                            QuickStatPill(value: game.stat(named: "AST")?.count ?? 0, label: "AST")
                            QuickStatPill(value: game.stat(named: "SAV")?.count ?? 0, label: "SAV")
                            QuickStatPill(value: game.stat(named: "SOT")?.made ?? 0, label: "SOT")
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }

            Section("Game Info") {
                if !game.opponent.isEmpty {
                    LabeledContent("Opponent", value: game.opponent)
                }
                LabeledContent("Date", value: game.formattedDate)
                if !game.location.isEmpty {
                    LabeledContent("Location", value: game.location)
                }
                LabeledContent("Status", value: game.isCompleted ? "Completed" : "In Progress")
            }

            Section("Player Stats") {
                ForEach(sortedPersonStats) { pgs in
                    if let person = pgs.person {
                        PersonStatsRow(person: person, stats: pgs)
                    }
                }
            }

            if !game.notes.isEmpty {
                Section("Notes") {
                    Text(game.notes)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if game.isCompleted {
                    Button {
                        showingSummary = true
                    } label: {
                        Label("View & Share Summary", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        showingTracking = true
                    } label: {
                        Label("Continue Tracking", systemImage: "play.fill")
                    }
                }
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game Details" : "vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSummary) {
            GameSummaryView(game: game)
        }
        .fullScreenCover(isPresented: $showingTracking) {
            GameTrackingView(game: game)
        }
    }
}

struct PersonStatsRow: View {
    let person: Person
    let stats: PersonGameStats

    private var plusMinusColor: Color {
        let pm = stats.totalPlusMinus
        if pm > 0 { return .green }
        if pm < 0 { return .red }
        return .secondary
    }

    private var hasShifts: Bool {
        !stats.completedShifts.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(person.displayName)
                    .font(.headline)
                Spacer()

                if hasShifts {
                    // Show plus/minus if shifts were tracked
                    Text(stats.formattedTotalPlusMinus)
                        .font(.subheadline.bold())
                        .foregroundStyle(plusMinusColor)
                        .padding(.trailing, 8)
                }

                Text("\(stats.totalPoints) pts")
                    .font(.headline)
                    .foregroundStyle(.accent)
            }

            HStack(spacing: 16) {
                ForEach(stats.stats?.filter { $0.total > 0 } ?? [], id: \.id) { stat in
                    if let def = stat.definition {
                        VStack(spacing: 2) {
                            Text(stat.displayValue)
                                .font(.subheadline.bold())
                            Text(def.shortName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Show shift info if tracked
                if hasShifts {
                    VStack(spacing: 2) {
                        Text("\(stats.completedShifts.count)")
                            .font(.subheadline.bold())
                        Text("SHIFTS")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text(stats.formattedTotalShiftTime)
                            .font(.subheadline.bold())
                        Text("TIME")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickStatPill: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 50)
    }
}

#Preview {
    NavigationStack {
        GameDetailView(game: Game(opponent: "Lakers", location: "Home Gym"))
    }
    .modelContainer(for: Game.self, inMemory: true)
}
