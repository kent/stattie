import SwiftUI
import SwiftData
import Charts

struct PersonStatsOverTimeView: View {
    @Environment(\.modelContext) private var modelContext
    let player: Person

    @State private var selectedStat: StatType = .points
    @State private var timeRange: TimeRange = .all

    enum StatType: String, CaseIterable {
        case points = "Points"
        case rebounds = "Rebounds"
        case assists = "Assists"
        case steals = "Steals"
        case fouls = "Fouls"
        case drives = "Drives"
        case greatPlays = "Great Plays"
        case twoPointers = "2PT Made"
        case threePointers = "3PT Made"
        case freeThrows = "FT Made"
        case offensiveRebounds = "Off. Rebounds"
        case defensiveRebounds = "Def. Rebounds"

        var color: Color {
            switch self {
            case .points: return .blue
            case .rebounds: return .green
            case .assists: return .mint
            case .steals: return .indigo
            case .fouls: return .red
            case .drives: return .cyan
            case .greatPlays: return .yellow
            case .twoPointers: return .blue
            case .threePointers: return .purple
            case .freeThrows: return .orange
            case .offensiveRebounds: return .teal
            case .defensiveRebounds: return .green
            }
        }

        var shortName: String {
            switch self {
            case .points: return "PTS"
            case .rebounds: return "REB"
            case .assists: return "AST"
            case .steals: return "STL"
            case .fouls: return "PF"
            case .drives: return "DRV"
            case .greatPlays: return "GP"
            case .twoPointers: return "2PT"
            case .threePointers: return "3PT"
            case .freeThrows: return "FT"
            case .offensiveRebounds: return "OREB"
            case .defensiveRebounds: return "DREB"
            }
        }
    }

    enum TimeRange: String, CaseIterable {
        case last10 = "Last 10"
        case last20 = "Last 20"
        case all = "All Games"

        var limit: Int? {
            switch self {
            case .last10: return 10
            case .last20: return 20
            case .all: return nil
            }
        }
    }

    var sortedGameStats: [PersonGameStats] {
        let allStats = (player.gameStats ?? [])
            .filter { $0.game != nil }
            .sorted { ($0.game?.gameDate ?? .distantPast) < ($1.game?.gameDate ?? .distantPast) }

        if let limit = timeRange.limit {
            return Array(allStats.suffix(limit))
        }
        return allStats
    }

    var chartData: [(date: Date, value: Int, gameNumber: Int)] {
        sortedGameStats.enumerated().map { index, pgs in
            let value: Int = statValue(for: selectedStat, from: pgs)
            return (date: pgs.game?.gameDate ?? Date(), value: value, gameNumber: index + 1)
        }
    }

    private func statValue(for stat: StatType, from pgs: PersonGameStats) -> Int {
        switch stat {
        case .points: return pgs.totalPoints
        case .rebounds: return pgs.totalRebounds
        case .assists: return pgs.totalAssists
        case .steals: return pgs.totalSteals
        case .fouls: return pgs.totalFouls
        case .drives: return pgs.stat(forName: "DRV")?.count ?? 0
        case .greatPlays: return pgs.stat(forName: "GP")?.count ?? 0
        case .twoPointers: return pgs.stat(forName: "2PT")?.made ?? 0
        case .threePointers: return pgs.stat(forName: "3PT")?.made ?? 0
        case .freeThrows: return pgs.stat(forName: "FT")?.made ?? 0
        case .offensiveRebounds: return pgs.stat(forName: "OREB")?.count ?? 0
        case .defensiveRebounds: return pgs.stat(forName: "DREB")?.count ?? 0
        }
    }

    var averageValue: Double {
        guard !chartData.isEmpty else { return 0 }
        return Double(chartData.reduce(0) { $0 + $1.value }) / Double(chartData.count)
    }

    var maxValue: Int {
        chartData.map { $0.value }.max() ?? 0
    }

    var minValue: Int {
        chartData.map { $0.value }.min() ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stat type dropdown
                HStack {
                    Text("Stat:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Menu {
                        ForEach(StatType.allCases, id: \.self) { stat in
                            Button {
                                selectedStat = stat
                            } label: {
                                HStack {
                                    Text(stat.rawValue)
                                    if selectedStat == stat {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedStat.rawValue)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedStat.color.opacity(0.15))
                        .foregroundStyle(selectedStat.color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if chartData.isEmpty {
                    ContentUnavailableView(
                        "No Game Data",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Play some games to see stats over time")
                    )
                    .frame(height: 300)
                } else {
                    // Main chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedStat.rawValue)
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(chartData, id: \.gameNumber) { item in
                            LineMark(
                                x: .value("Game", item.gameNumber),
                                y: .value(selectedStat.rawValue, item.value)
                            )
                            .foregroundStyle(selectedStat.color)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Game", item.gameNumber),
                                y: .value(selectedStat.rawValue, item.value)
                            )
                            .foregroundStyle(selectedStat.color)

                            RuleMark(y: .value("Average", averageValue))
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineStyle(StrokeStyle(dash: [5, 5]))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxisLabel("Game #", position: .bottom)
                        .chartYAxisLabel(selectedStat.rawValue, position: .leading)
                        .frame(height: 250)
                        .padding()
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    .padding(.horizontal)

                    // Stats summary
                    VStack(spacing: 16) {
                        Text("Summary")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 16) {
                            StatSummaryCard(
                                title: "Average",
                                value: String(format: "%.1f", averageValue),
                                color: selectedStat.color
                            )

                            StatSummaryCard(
                                title: "High",
                                value: "\(maxValue)",
                                color: .green
                            )

                            StatSummaryCard(
                                title: "Low",
                                value: "\(minValue)",
                                color: .red
                            )
                        }

                        StatSummaryCard(
                            title: "Games Played",
                            value: "\(chartData.count)",
                            color: .secondary
                        )
                    }
                    .padding(.horizontal)

                    // Recent games list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Games")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(sortedGameStats.suffix(10).reversed()) { pgs in
                            if let game = pgs.game {
                                GameStatRow(game: game, playerStats: pgs, selectedStat: selectedStat)
                            }
                        }
                    }
                    .padding(.top)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Stats Over Time")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Components

struct StatSummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct GameStatRow: View {
    let game: Game
    let playerStats: PersonGameStats
    let selectedStat: PersonStatsOverTimeView.StatType

    private var statValue: Int {
        switch selectedStat {
        case .points: return playerStats.totalPoints
        case .rebounds: return playerStats.totalRebounds
        case .assists: return playerStats.totalAssists
        case .steals: return playerStats.totalSteals
        case .fouls: return playerStats.totalFouls
        case .drives: return playerStats.stat(forName: "DRV")?.count ?? 0
        case .greatPlays: return playerStats.stat(forName: "GP")?.count ?? 0
        case .twoPointers: return playerStats.stat(forName: "2PT")?.made ?? 0
        case .threePointers: return playerStats.stat(forName: "3PT")?.made ?? 0
        case .freeThrows: return playerStats.stat(forName: "FT")?.made ?? 0
        case .offensiveRebounds: return playerStats.stat(forName: "OREB")?.count ?? 0
        case .defensiveRebounds: return playerStats.stat(forName: "DREB")?.count ?? 0
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
                    .font(.subheadline.bold())
                Text(game.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(statValue)")
                .font(.title2.bold())
                .foregroundStyle(selectedStat.color)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}

struct StatPill: View {
    let label: String
    let value: Int
    let isHighlighted: Bool
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundStyle(isHighlighted ? color : .primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(width: 36)
    }
}

#Preview {
    NavigationStack {
        PersonStatsOverTimeView(player: Person(firstName: "Jack", lastName: "James", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: [Person.self, PersonGameStats.self, Game.self, Stat.self], inMemory: true)
}
