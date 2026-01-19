import SwiftUI
import SwiftData

struct GameSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game

    @State private var showingShareSheet = false

    // Get stats sorted by category
    var shootingStats: [Stat] {
        (game.stats ?? []).filter { ["2PT", "3PT", "FT"].contains($0.statName) }
            .sorted { statOrder($0.statName) < statOrder($1.statName) }
    }

    var otherStats: [Stat] {
        (game.stats ?? []).filter { ["DREB", "OREB", "STL", "PF"].contains($0.statName) }
            .sorted { statOrder($0.statName) < statOrder($1.statName) }
    }

    var totalRebounds: Int {
        let dreb = game.stat(named: "DREB")?.count ?? 0
        let oreb = game.stat(named: "OREB")?.count ?? 0
        return dreb + oreb
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with score
                    VStack(spacing: 8) {
                        if !game.opponent.isEmpty {
                            Text("vs \(game.opponent)")
                                .font(.title2.bold())
                        }

                        Text("\(game.totalPoints)")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(.blue)

                        Text("Total Points")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(game.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Shooting Stats Table
                    if !shootingStats.isEmpty || game.totalPoints > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SHOOTING")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // Header row
                                HStack {
                                    Text("Stat")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Made")
                                        .frame(width: 50)
                                    Text("Att")
                                        .frame(width: 50)
                                    Text("Pct")
                                        .frame(width: 50)
                                    Text("Pts")
                                        .frame(width: 50)
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemGroupedBackground))

                                // 2PT row
                                StatRow(
                                    name: "2-Pointers",
                                    made: game.stat(named: "2PT")?.made ?? 0,
                                    attempts: (game.stat(named: "2PT")?.made ?? 0) + (game.stat(named: "2PT")?.missed ?? 0),
                                    pointValue: 2
                                )

                                Divider()

                                // 3PT row
                                StatRow(
                                    name: "3-Pointers",
                                    made: game.stat(named: "3PT")?.made ?? 0,
                                    attempts: (game.stat(named: "3PT")?.made ?? 0) + (game.stat(named: "3PT")?.missed ?? 0),
                                    pointValue: 3
                                )

                                Divider()

                                // FT row
                                StatRow(
                                    name: "Free Throws",
                                    made: game.stat(named: "FT")?.made ?? 0,
                                    attempts: (game.stat(named: "FT")?.made ?? 0) + (game.stat(named: "FT")?.missed ?? 0),
                                    pointValue: 1
                                )
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Other Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OTHER STATS")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            StatBox(
                                title: "Rebounds",
                                value: totalRebounds,
                                detail: "D: \(game.stat(named: "DREB")?.count ?? 0) / O: \(game.stat(named: "OREB")?.count ?? 0)"
                            )

                            StatBox(
                                title: "Steals",
                                value: game.stat(named: "STL")?.count ?? 0,
                                detail: nil
                            )

                            StatBox(
                                title: "Fouls",
                                value: game.stat(named: "PF")?.count ?? 0,
                                detail: nil
                            )
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Game Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [generateShareText()])
            }
        }
    }

    private func statOrder(_ name: String) -> Int {
        switch name {
        case "2PT": return 0
        case "3PT": return 1
        case "FT": return 2
        case "DREB": return 3
        case "OREB": return 4
        case "STL": return 5
        case "PF": return 6
        default: return 99
        }
    }

    private func generateShareText() -> String {
        var text = ""
        if !game.opponent.isEmpty {
            text += "vs \(game.opponent)\n"
        }
        text += "\(game.totalPoints) Points\n"
        text += "\(game.formattedDate)\n\n"

        text += "SHOOTING\n"
        let twoPt = game.stat(named: "2PT")
        let threePt = game.stat(named: "3PT")
        let ft = game.stat(named: "FT")

        text += "2PT: \(twoPt?.made ?? 0)/\(((twoPt?.made ?? 0) + (twoPt?.missed ?? 0)))\n"
        text += "3PT: \(threePt?.made ?? 0)/\(((threePt?.made ?? 0) + (threePt?.missed ?? 0)))\n"
        text += "FT: \(ft?.made ?? 0)/\(((ft?.made ?? 0) + (ft?.missed ?? 0)))\n\n"

        text += "OTHER\n"
        text += "Rebounds: \(totalRebounds) (D: \(game.stat(named: "DREB")?.count ?? 0), O: \(game.stat(named: "OREB")?.count ?? 0))\n"
        text += "Steals: \(game.stat(named: "STL")?.count ?? 0)\n"
        text += "Fouls: \(game.stat(named: "PF")?.count ?? 0)\n"

        return text
    }
}

// MARK: - Components

struct StatRow: View {
    let name: String
    let made: Int
    let attempts: Int
    let pointValue: Int

    var percentage: String {
        guard attempts > 0 else { return "-" }
        let pct = Double(made) / Double(attempts) * 100
        return String(format: "%.0f%%", pct)
    }

    var points: Int {
        made * pointValue
    }

    var body: some View {
        HStack {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(made)")
                .frame(width: 50)
            Text("\(attempts)")
                .frame(width: 50)
            Text(percentage)
                .frame(width: 50)
            Text("\(points)")
                .frame(width: 50)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

struct StatBox: View {
    let title: String
    let value: Int
    let detail: String?

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let detail = detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    GameSummaryView(game: Game(opponent: "Lakers", location: "Home Gym"))
        .modelContainer(for: [Game.self, Stat.self], inMemory: true)
}
