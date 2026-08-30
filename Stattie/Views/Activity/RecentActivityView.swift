import SwiftUI
import SwiftData

struct RecentActivityView: View {
    @Query private var users: [User]
    @Query(sort: \Game.gameDate, order: .reverse) private var allGames: [Game]

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    private var recentGames: [Game] {
        allGames
            .filter { $0.isCompleted && $0.isOwned(by: currentUser) }
            .prefix(20)
            .map { $0 }
    }

    private var groupedByDate: [(String, [Game])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentGames) { game -> String in
            if calendar.isDateInToday(game.gameDate) {
                return "Today"
            } else if calendar.isDateInYesterday(game.gameDate) {
                return "Yesterday"
            } else if calendar.isDate(game.gameDate, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: game.gameDate)
            }
        }

        // Sort groups in order: Today, Yesterday, This Week, then by date
        let order = ["Today", "Yesterday", "This Week"]
        return grouped.sorted { a, b in
            let aIndex = order.firstIndex(of: a.key) ?? Int.max
            let bIndex = order.firstIndex(of: b.key) ?? Int.max
            if aIndex != bIndex {
                return aIndex < bIndex
            }
            // Both are month/year strings, sort by date
            return (a.value.first?.gameDate ?? Date()) > (b.value.first?.gameDate ?? Date())
        }
    }

    var body: some View {
        ScrollView {
            if recentGames.isEmpty {
                ContentUnavailableView {
                    Label("No Activity Yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Completed games will appear here")
                }
                .frame(minHeight: 300)
            } else {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(groupedByDate, id: \.0) { section, games in
                        Section {
                            ForEach(games) { game in
                                ActivityRow(game: game)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)

                                if game.id != games.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        } header: {
                            HStack {
                                Text(section)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.bar)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recent Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ActivityRow: View {
    let game: Game

    private var playerNames: String {
        let names = (game.personStats ?? []).compactMap { $0.person?.firstName }
        if names.isEmpty { return "Unknown" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return "\(names[0]) & \(names[1])" }
        return "\(names[0]) +\(names.count - 1)"
    }

    private var topStat: String {
        let stats = game.personStats ?? []
        if let best = stats.max(by: { $0.totalPoints < $1.totalPoints }), best.totalPoints > 0 {
            if let player = best.person {
                return "\(player.firstName): \(best.totalPoints) pts"
            }
            return "\(best.totalPoints) pts"
        }
        return "No points"
    }

    private var sportIcon: String {
        game.sport?.iconName ?? "sportscourt.fill"
    }

    private var sportColor: Color {
        if let sportName = game.sport?.name.lowercased() {
            switch sportName {
            case "basketball": return .orange
            case "soccer": return .green
            case "ice hockey", "hockey": return .blue
            case "baseball", "softball": return .red
            case "american football", "canadian football": return .brown
            case "lacrosse": return .purple
            case "volleyball": return .yellow
            case "rugby": return .mint
            case "handball", "field hockey", "water polo": return .teal
            case "cricket": return .indigo
            case "tennis": return .green
            case "golf": return .mint
            case "wrestling": return .orange
            case "curling": return .cyan
            default: return .accentColor
            }
        }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Sport icon
            ZStack {
                Circle()
                    .fill(sportColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: sportIcon)
                    .font(.body)
                    .foregroundStyle(sportColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(playerNames)
                        .font(.headline)

                    if !game.opponent.isEmpty {
                        Text("vs \(game.opponent)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(topStat)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(game.gameDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Total points badge
            if game.totalPoints > 0 {
                VStack(spacing: 2) {
                    Text("\(game.totalPoints)")
                        .font(.title3.bold())
                        .foregroundStyle(.accent)
                    Text("pts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Activity Summary Card (for use in other views)

struct ActivitySummaryCard: View {
    @Query private var users: [User]
    @Query(sort: \Game.gameDate, order: .reverse) private var allGames: [Game]

    private var currentUser: User? {
        users.resolvedCurrentUser
    }

    private var recentGames: [Game] {
        Array(allGames.filter { $0.isCompleted && $0.isOwned(by: currentUser) }.prefix(3))
    }

    private var hasActivity: Bool {
        !recentGames.isEmpty
    }

    var body: some View {
        if hasActivity {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                    Spacer()
                    NavigationLink {
                        RecentActivityView()
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                    }
                }

                ForEach(recentGames) { game in
                    MiniActivityRow(game: game)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct MiniActivityRow: View {
    let game: Game

    private var playerName: String {
        (game.personStats ?? []).first?.person?.firstName ?? "Game"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(playerName)
                .font(.subheadline)

            Text("scored \(game.totalPoints) pts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(game.gameDate, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    NavigationStack {
        RecentActivityView()
    }
    .modelContainer(for: Game.self, inMemory: true)
}
