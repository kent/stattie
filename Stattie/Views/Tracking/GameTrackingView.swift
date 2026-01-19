import SwiftUI
import SwiftData

struct GameTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    @State private var showingEndGameAlert = false
    @State private var showingSummary = false

    var totalPoints: Int {
        game.totalPoints
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score display
                    VStack(spacing: 4) {
                        Text("\(totalPoints)")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("POINTS")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Shooting buttons
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatButton(
                                title: "2 PTS",
                                subtitle: madeString("2PT"),
                                color: .blue
                            ) {
                                recordMade("2PT", points: 2)
                            }

                            StatButton(
                                title: "3 PTS",
                                subtitle: madeString("3PT"),
                                color: .purple
                            ) {
                                recordMade("3PT", points: 3)
                            }
                        }

                        StatButton(
                            title: "FREE THROW",
                            subtitle: madeString("FT"),
                            color: .orange
                        ) {
                            recordMade("FT", points: 1)
                        }

                        // Miss buttons
                        HStack(spacing: 8) {
                            MissButton(title: "2PT Miss") { recordMiss("2PT", points: 2) }
                            MissButton(title: "3PT Miss") { recordMiss("3PT", points: 3) }
                            MissButton(title: "FT Miss") { recordMiss("FT", points: 1) }
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.vertical, 8)

                    // Other stats
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatButton(
                                title: "DEF REB",
                                subtitle: countString("DREB"),
                                color: .green
                            ) {
                                recordCount("DREB")
                            }

                            StatButton(
                                title: "OFF REB",
                                subtitle: countString("OREB"),
                                color: .teal
                            ) {
                                recordCount("OREB")
                            }
                        }

                        HStack(spacing: 12) {
                            StatButton(
                                title: "STEAL",
                                subtitle: countString("STL"),
                                color: .indigo
                            ) {
                                recordCount("STL")
                            }

                            StatButton(
                                title: "FOUL",
                                subtitle: countString("PF"),
                                color: .red
                            ) {
                                recordCount("PF")
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
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
                        showingEndGameAlert = true
                    }
                }
            }
            .alert("End Game?", isPresented: $showingEndGameAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Game", role: .destructive) {
                    game.isCompleted = true
                    try? modelContext.save()
                    showingSummary = true
                }
            } message: {
                Text("This will mark the game as completed.")
            }
            .sheet(isPresented: $showingSummary, onDismiss: { dismiss() }) {
                GameSummaryView(game: game)
            }
        }
    }

    // MARK: - Stat Recording

    private func getOrCreateStat(_ name: String, points: Int) -> Stat {
        if let existing = game.stat(named: name) {
            return existing
        }

        let stat = Stat(statName: name, pointValue: points)
        stat.game = game
        modelContext.insert(stat)

        if game.stats == nil { game.stats = [] }
        game.stats?.append(stat)

        return stat
    }

    private func recordMade(_ name: String, points: Int) {
        let stat = getOrCreateStat(name, points: points)
        stat.made += 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func recordMiss(_ name: String, points: Int) {
        let stat = getOrCreateStat(name, points: points)
        stat.missed += 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    private func recordCount(_ name: String) {
        let stat = getOrCreateStat(name, points: 0)
        stat.count += 1
        stat.timestamp = Date()
        try? modelContext.save()
    }

    // MARK: - Display Helpers

    private func madeString(_ name: String) -> String {
        if let stat = game.stat(named: name) {
            return "\(stat.made)/\(stat.made + stat.missed)"
        }
        return "0/0"
    }

    private func countString(_ name: String) -> String {
        if let stat = game.stat(named: name) {
            return "\(stat.count)"
        }
        return "0"
    }
}

// MARK: - Components

struct StatButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.headline)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct MissButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    GameTrackingView(game: Game(opponent: "Lakers"))
        .modelContainer(for: [Game.self, Stat.self], inMemory: true)
}
