import SwiftUI
import SwiftData
import Charts

struct PersonStatsOverTimeView: View {
    @Environment(\.modelContext) private var modelContext
    let player: Person

    @State private var selectedStat: StatType = .points
    @State private var selectedSportName: String = "Basketball"
    @State private var selectedCatalogShortName: String = ""
    @State private var selectedPositionID: String = "all"
    @State private var timeRange: TimeRange = .all

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

    private var availableSportNames: [String] {
        let names = (player.gameStats ?? []).compactMap { $0.game?.sport?.name }
        let unique = Array(Set(names)).sorted()
        return unique.isEmpty ? ["Basketball"] : unique
    }

    private var selectedSportProfile: SportProfile? {
        SportCatalog.profile(named: selectedSportName)
    }

    private var usesBasketballChart: Bool {
        selectedSportName == "Basketball"
    }

    private var chartStatTitle: String {
        if usesBasketballChart { return selectedStat.rawValue }
        if selectedCatalogShortName == "+/-" { return "Plus/Minus" }
        return selectedSportProfile?.spec(shortName: selectedCatalogShortName)?.name
            ?? selectedSportProfile?.primaryScoreLabel
            ?? "Stat"
    }

    private var catalogChartStats: [CatalogStatSpec] {
        guard let profile = selectedSportProfile else { return [] }
        if !profile.stats.isEmpty {
            return profile.stats.filter { profile.highlightShortNames.contains($0.shortName) }
        }
        return profile.highlightShortNames.enumerated().map { index, shortName in
            CatalogStatSpec(
                name: shortName,
                shortName: shortName,
                category: "highlight",
                sortOrder: index,
                iconName: "chart.bar.fill"
            )
        }
    }

    private var seasonPositionTotals: [PositionStatTotals] {
        PositionStatAggregator.seasonTotals(from: sortedGameStats)
    }

    private var availableSeasonPositions: [SoccerPosition] {
        seasonPositionTotals.compactMap(\.position)
    }

    private var selectedSeasonPosition: SoccerPosition? {
        SoccerPosition(rawValue: selectedPositionID)
    }

    var sortedGameStats: [PersonGameStats] {
        let allStats = (player.gameStats ?? [])
            .filter { $0.game != nil && $0.game?.isCompleted == true }
            .filter { stats in
                guard let sportName = stats.game?.sport?.name else { return true }
                return sportName == selectedSportName
            }
            .sorted { ($0.game?.gameDate ?? .distantPast) < ($1.game?.gameDate ?? .distantPast) }

        if let minDate = timeRange.dateFilter {
            return allStats.filter { ($0.game?.gameDate ?? .distantPast) >= minDate }
        }
        return allStats
    }

    var chartData: [(date: Date, value: Int, gameNumber: Int)] {
        sortedGameStats.enumerated().compactMap { index, pgs in
            if selectedSeasonPosition != nil {
                let shifts = (pgs.shifts ?? []).filter { $0.recordedPosition == selectedSeasonPosition }
                guard !shifts.isEmpty else { return nil }
                return (
                    date: pgs.game?.gameDate ?? Date(),
                    value: positionFilteredValue(from: shifts),
                    gameNumber: index + 1
                )
            }

            let value: Int
            if usesBasketballChart {
                value = statValue(for: selectedStat, from: pgs)
            } else if selectedCatalogShortName == "+/-" {
                value = pgs.totalPlusMinus
            } else if let spec = selectedSportProfile?.spec(shortName: selectedCatalogShortName) {
                value = spec.hasMadeAndMissed
                    ? pgs.aggregatedMade(forName: spec.shortName)
                    : pgs.aggregatedCount(forName: spec.shortName)
            } else {
                value = pgs.totalPoints
            }
            return (date: pgs.game?.gameDate ?? Date(), value: value, gameNumber: index + 1)
        }
    }

    private func positionFilteredValue(from shifts: [Shift]) -> Int {
        let totals = PositionStatAggregator.totals(from: shifts).first
        if usesBasketballChart {
            switch selectedStat {
            case .points: return totals?.points ?? 0
            case .plusMinus: return totals?.plusMinus ?? 0
            case .rebounds: return (totals?.count(forName: "DREB") ?? 0) + (totals?.count(forName: "OREB") ?? 0)
            case .assists: return totals?.count(forName: "AST") ?? 0
            case .steals: return totals?.count(forName: "STL") ?? 0
            case .fouls: return totals?.count(forName: "PF") ?? 0
            case .turnovers: return totals?.count(forName: "TO") ?? 0
            case .missedDrives: return totals?.count(forName: "MD") ?? 0
            case .badPlaysOffense: return totals?.count(forName: "BPO") ?? 0
            case .badPlaysDefense: return totals?.count(forName: "BPD") ?? 0
            case .greatPlaysOffense: return totals?.count(forName: "GPO") ?? 0
            case .greatPlaysDefense: return totals?.count(forName: "GPD") ?? 0
            case .twoPointers: return totals?.madeCount(forName: "2PT") ?? 0
            case .threePointers: return totals?.madeCount(forName: "3PT") ?? 0
            case .freeThrows: return totals?.madeCount(forName: "FT") ?? 0
            case .offensiveRebounds: return totals?.count(forName: "OREB") ?? 0
            case .defensiveRebounds: return totals?.count(forName: "DREB") ?? 0
            }
        }
        if selectedCatalogShortName == "+/-" {
            return totals?.plusMinus ?? 0
        }
        if let spec = selectedSportProfile?.spec(shortName: selectedCatalogShortName) {
            return spec.hasMadeAndMissed
                ? (totals?.madeCount(forName: spec.shortName) ?? 0)
                : (totals?.count(forName: spec.shortName) ?? 0)
        }
        return totals?.points ?? 0
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
                if availableSportNames.count > 1 {
                    Picker("Sport", selection: $selectedSportName) {
                        ForEach(availableSportNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedSportName) { _, newValue in
                        selectedCatalogShortName = SportCatalog.profile(named: newValue)?.highlightShortNames.first ?? ""
                        selectedPositionID = "all"
                    }
                }

                if !availableSeasonPositions.isEmpty {
                    Picker("Position", selection: $selectedPositionID) {
                        Text("All Positions").tag("all")
                        ForEach(availableSeasonPositions) { position in
                            Text(position.displayName).tag(position.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }

                if !seasonPositionTotals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("By Position")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(seasonPositionTotals) { totals in
                            PositionBreakdownCard(
                                totals: totals,
                                sportName: selectedSportName
                            )
                            .padding(.horizontal)
                        }
                    }
                }

                HStack {
                    Text("Stat:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Menu {
                        if usesBasketballChart {
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
                        } else {
                            Button {
                                selectedCatalogShortName = "+/-"
                            } label: {
                                HStack {
                                    Text("Plus/Minus")
                                    if selectedCatalogShortName == "+/-" {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            ForEach(catalogChartStats) { spec in
                                Button {
                                    selectedCatalogShortName = spec.shortName
                                } label: {
                                    HStack {
                                        Text(spec.name)
                                        if selectedCatalogShortName == spec.shortName {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(chartStatTitle)
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
                        Text(chartStatTitle)
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
        .onAppear {
            if let first = availableSportNames.first {
                selectedSportName = first
                if first != "Basketball" {
                    selectedCatalogShortName = SportCatalog.profile(named: first)?.highlightShortNames.first ?? "+/-"
                }
            }
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

#Preview {
    NavigationStack {
        PersonStatsOverTimeView(player: Person(firstName: "Jack", lastName: "Fenwick", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: [Person.self, PersonGameStats.self, Game.self, Stat.self], inMemory: true)
}
