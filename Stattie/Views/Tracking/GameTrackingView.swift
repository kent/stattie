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

    var totalRebounds: Int {
        (game.stat(named: "DREB")?.count ?? 0) + (game.stat(named: "OREB")?.count ?? 0)
    }

    var totalAssists: Int {
        game.stat(named: "AST")?.count ?? 0
    }

    var totalSteals: Int {
        game.stat(named: "STL")?.count ?? 0
    }

    private var doubleDigitCategories: Int {
        var count = 0
        if totalPoints >= 10 { count += 1 }
        if totalRebounds >= 10 { count += 1 }
        if totalAssists >= 10 { count += 1 }
        if totalSteals >= 10 { count += 1 }
        return count
    }

    var hasDoubleDouble: Bool {
        doubleDigitCategories >= 2
    }

    var hasTripleDouble: Bool {
        doubleDigitCategories >= 3
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Score display
                HStack {
                    Text("\(totalPoints)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.blue)
                    Text("PTS")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Achievements inline
                    if hasTripleDouble {
                        Label("Triple Double", systemImage: "star.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                    } else if hasDoubleDouble {
                        Label("Double Double", systemImage: "star.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Shooting buttons - 3 across
                HStack(spacing: 8) {
                    CompactStatButton(title: "2 PTS", subtitle: madeString("2PT"), color: .blue) {
                        recordMade("2PT", points: 2)
                    }
                    CompactStatButton(title: "3 PTS", subtitle: madeString("3PT"), color: .purple) {
                        recordMade("3PT", points: 3)
                    }
                    CompactStatButton(title: "FT", subtitle: madeString("FT"), color: .orange) {
                        recordMade("FT", points: 1)
                    }
                }
                .padding(.horizontal)

                // Miss buttons
                HStack(spacing: 6) {
                    MissButton(title: "2PT Miss") { recordMiss("2PT", points: 2) }
                    MissButton(title: "3PT Miss") { recordMiss("3PT", points: 3) }
                    MissButton(title: "FT Miss") { recordMiss("FT", points: 1) }
                }
                .padding(.horizontal)

                Divider().padding(.vertical, 4)

                // Other stats - 3 columns
                HStack(spacing: 8) {
                    CompactStatButton(title: "D-REB", subtitle: countString("DREB"), color: .green) {
                        recordCount("DREB")
                    }
                    CompactStatButton(title: "O-REB", subtitle: countString("OREB"), color: .teal) {
                        recordCount("OREB")
                    }
                    CompactStatButton(title: "STEAL", subtitle: countString("STL"), color: .indigo) {
                        recordCount("STL")
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 8) {
                    CompactStatButton(title: "ASSIST", subtitle: countString("AST"), color: .mint) {
                        recordCount("AST")
                    }
                    CompactStatButton(title: "DRIVE", subtitle: countString("DRV"), color: .cyan) {
                        recordCount("DRV")
                    }
                    CompactStatButton(title: "FOUL", subtitle: countString("PF"), color: .red) {
                        recordCount("PF")
                    }
                }
                .padding(.horizontal)

                CompactStatButton(title: "GREAT PLAY", subtitle: countString("GP"), color: .yellow) {
                    recordCount("GP")
                }
                .padding(.horizontal)

                Spacer()
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

struct CompactStatButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption.bold())
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MissButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding()
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    GameTrackingView(game: Game(opponent: "Lakers"))
        .modelContainer(for: [Game.self, Stat.self], inMemory: true)
}
