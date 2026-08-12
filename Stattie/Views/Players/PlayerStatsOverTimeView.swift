import SwiftUI
import SwiftData
import Charts

struct PersonStatsOverTimeView: View {
    @Environment(\.modelContext) private var modelContext
    let player: Person

    @State private var selectedStat: StatType = .points
    @State private var timeRange: TimeRange = .all
    @State private var showingShareSheet = false

    enum StatType: String, CaseIterable {
        case points = "Points"
        case plusMinus = "Plus/Minus"
        case rebounds = "Rebounds"
        case assists = "Assists"
        case steals = "Steals"
        case fouls = "Fouls"
        case turnovers = "Turnovers"
        case missedDrives = "Missed Drives"
        case badPlaysOffense = "Bad Plays Offense"
        case badPlaysDefense = "Bad Plays Defense"
        case greatPlaysOffense = "Great Plays Offense"
        case greatPlaysDefense = "Great Plays Defense"
        case twoPointers = "2PT Made"
        case threePointers = "3PT Made"
        case freeThrows = "FT Made"
        case offensiveRebounds = "Off. Rebounds"
        case defensiveRebounds = "Def. Rebounds"

        var color: Color {
            switch self {
            case .points: return .blue
            case .plusMinus: return .purple
            case .rebounds: return .green
            case .assists: return .mint
            case .steals: return .indigo
            case .fouls: return .red
            case .turnovers: return .brown
            case .missedDrives: return .orange
            case .badPlaysOffense: return .red
            case .badPlaysDefense: return .pink
            case .greatPlaysOffense: return .yellow
            case .greatPlaysDefense: return .green
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
            case .plusMinus: return "+/-"
            case .rebounds: return "REB"
            case .assists: return "AST"
            case .steals: return "STL"
            case .fouls: return "PF"
            case .turnovers: return "TO"
            case .missedDrives: return "MD"
            case .badPlaysOffense: return "BPO"
            case .badPlaysDefense: return "BPD"
            case .greatPlaysOffense: return "GPO"
            case .greatPlaysDefense: return "GPD"
            case .twoPointers: return "2PT"
            case .threePointers: return "3PT"
            case .freeThrows: return "FT"
            case .offensiveRebounds: return "OREB"
            case .defensiveRebounds: return "DREB"
            }
        }

        /// Whether this stat can be negative (affects chart display)
        var canBeNegative: Bool {
            self == .plusMinus
        }
    }

    enum TimeRange: String, CaseIterable {
        case thisMonth = "This Month"
        case last3Months = "3 Months"
        case thisYear = "This Year"
        case all = "All Time"

        var dateFilter: Date? {
            let calendar = Calendar.current
            switch self {
            case .thisMonth:
                return calendar.date(byAdding: .month, value: -1, to: Date())
            case .last3Months:
                return calendar.date(byAdding: .month, value: -3, to: Date())
            case .thisYear:
                return calendar.date(from: calendar.dateComponents([.year], from: Date()))
            case .all:
                return nil
            }
        }
    }

    var sortedGameStats: [PersonGameStats] {
        let allStats = (player.gameStats ?? [])
            .filter { $0.game != nil && $0.game?.isCompleted == true }
            .sorted { ($0.game?.gameDate ?? .distantPast) < ($1.game?.gameDate ?? .distantPast) }

        if let minDate = timeRange.dateFilter {
            return allStats.filter { ($0.game?.gameDate ?? .distantPast) >= minDate }
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
        case .plusMinus: return pgs.totalPlusMinus
        case .rebounds: return pgs.totalRebounds
        case .assists: return pgs.totalAssists
        case .steals: return pgs.totalSteals
        case .fouls: return pgs.totalFouls
        case .turnovers: return pgs.aggregatedCount(forName: "TO")
        case .missedDrives: return pgs.aggregatedCount(forName: "MD")
        case .badPlaysOffense: return pgs.aggregatedCount(forName: "BPO")
        case .badPlaysDefense: return pgs.aggregatedCount(forName: "BPD")
        case .greatPlaysOffense: return pgs.aggregatedCount(forName: "GPO")
        case .greatPlaysDefense: return pgs.aggregatedCount(forName: "GPD")
        case .twoPointers: return pgs.aggregatedMade(forName: "2PT")
        case .threePointers: return pgs.aggregatedMade(forName: "3PT")
        case .freeThrows: return pgs.aggregatedMade(forName: "FT")
        case .offensiveRebounds: return pgs.aggregatedCount(forName: "OREB")
        case .defensiveRebounds: return pgs.aggregatedCount(forName: "DREB")
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
                            .foregroundStyle(selectedStat.canBeNegative ? (item.value >= 0 ? Color.green : Color.red) : selectedStat.color)

                            RuleMark(y: .value("Average", averageValue))
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineStyle(StrokeStyle(dash: [5, 5]))

                            // Zero line for plus/minus
                            if selectedStat.canBeNegative {
                                RuleMark(y: .value("Zero", 0))
                                    .foregroundStyle(.secondary.opacity(0.3))
                            }
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

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 16)], spacing: 16) {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share stats")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareStatsSheet(player: player, stats: chartData, selectedStat: selectedStat, averageValue: averageValue)
        }
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
        case .plusMinus: return playerStats.totalPlusMinus
        case .rebounds: return playerStats.totalRebounds
        case .assists: return playerStats.totalAssists
        case .steals: return playerStats.totalSteals
        case .fouls: return playerStats.totalFouls
        case .turnovers: return playerStats.aggregatedCount(forName: "TO")
        case .missedDrives: return playerStats.aggregatedCount(forName: "MD")
        case .badPlaysOffense: return playerStats.aggregatedCount(forName: "BPO")
        case .badPlaysDefense: return playerStats.aggregatedCount(forName: "BPD")
        case .greatPlaysOffense: return playerStats.aggregatedCount(forName: "GPO")
        case .greatPlaysDefense: return playerStats.aggregatedCount(forName: "GPD")
        case .twoPointers: return playerStats.aggregatedMade(forName: "2PT")
        case .threePointers: return playerStats.aggregatedMade(forName: "3PT")
        case .freeThrows: return playerStats.aggregatedMade(forName: "FT")
        case .offensiveRebounds: return playerStats.aggregatedCount(forName: "OREB")
        case .defensiveRebounds: return playerStats.aggregatedCount(forName: "DREB")
        }
    }

    /// Display string for stat value (handles +/- formatting)
    private var statDisplayValue: String {
        if selectedStat == .plusMinus {
            return statValue > 0 ? "+\(statValue)" : "\(statValue)"
        }
        return "\(statValue)"
    }

    /// Color for the stat value (special handling for +/-)
    private var statDisplayColor: Color {
        if selectedStat == .plusMinus {
            if statValue > 0 { return .green }
            if statValue < 0 { return .red }
            return .secondary
        }
        return selectedStat.color
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

            Text(statDisplayValue)
                .font(.title2.bold())
                .foregroundStyle(statDisplayColor)
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
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 36)
    }
}

// MARK: - Share Stats Sheet

struct ShareStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let player: Person
    let stats: [(date: Date, value: Int, gameNumber: Int)]
    let selectedStat: PersonStatsOverTimeView.StatType
    let averageValue: Double

    @State private var showingActivitySheet = false

    var shareText: String {
        let gamesCount = stats.count
        let highValue = stats.map { $0.value }.max() ?? 0

        return """
        \(player.fullName) Stats 📊

        \(selectedStat.rawValue) over \(gamesCount) games:
        • Average: \(String(format: "%.1f", averageValue))
        • Career High: \(highValue)

        Tracked with Stattie 📱
        """
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preview card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(player.fullName)
                                .font(.title2.bold())
                        }
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.largeTitle)
                            .foregroundStyle(.accent)
                    }

                    Divider()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 24)], spacing: 16) {
                        VStack {
                            Text(String(format: "%.1f", averageValue))
                                .scaledFont(size: 36, weight: .bold, relativeTo: .title1)
                                .foregroundStyle(selectedStat.color)
                            Text("Avg \(selectedStat.shortName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(stats.map { $0.value }.max() ?? 0)")
                                .scaledFont(size: 36, weight: .bold, relativeTo: .title1)
                                .foregroundStyle(.green)
                            Text("High")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(stats.count)")
                                .scaledFont(size: 36, weight: .bold, relativeTo: .title1)
                            Text("Games")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Tracked with Stattie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 10)
                .padding(.horizontal)

                Spacer()

                Button {
                    showingActivitySheet = true
                } label: {
                    Label("Share Stats", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle("Share Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingActivitySheet) {
                ActivityView(items: [shareText])
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        PersonStatsOverTimeView(player: Person(firstName: "Jack", lastName: "Fenwick", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: [Person.self, PersonGameStats.self, Game.self, Stat.self], inMemory: true)
}
