import SwiftUI
import SwiftData

struct PlayerComparisonView: View {
    @Query(sort: \Person.jerseyNumber) private var allPlayers: [Person]

    @State private var player1: Person?
    @State private var player2: Person?

    private var activePlayers: [Person] {
        allPlayers.filter { $0.isActive && $0.completedGamesCount > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player selectors
                HStack(spacing: 16) {
                    PlayerSelector(
                        title: "Player 1",
                        selectedPlayer: $player1,
                        availablePlayers: activePlayers,
                        excludePlayer: player2
                    )

                    Text("vs")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    PlayerSelector(
                        title: "Player 2",
                        selectedPlayer: $player2,
                        availablePlayers: activePlayers,
                        excludePlayer: player1
                    )
                }
                .padding()

                if let p1 = player1, let p2 = player2 {
                    // Comparison stats
                    VStack(spacing: 16) {
                        ComparisonHeader(player1: p1, player2: p2)

                        Divider()

                        ComparisonRow(
                            label: "Games Played",
                            value1: p1.completedGamesCount,
                            value2: p2.completedGamesCount
                        )

                        ComparisonRow(
                            label: "Avg Points",
                            value1: p1.averagePointsPerGame,
                            value2: p2.averagePointsPerGame,
                            format: "%.1f"
                        )

                        ComparisonRow(
                            label: "Career High",
                            value1: p1.careerHighPoints,
                            value2: p2.careerHighPoints
                        )

                        ComparisonRow(
                            label: "Total Points",
                            value1: p1.totalCareerPoints,
                            value2: p2.totalCareerPoints
                        )

                        ComparisonRow(
                            label: "High Rebounds",
                            value1: p1.careerHighRebounds,
                            value2: p2.careerHighRebounds
                        )

                        ComparisonRow(
                            label: "High Assists",
                            value1: p1.careerHighAssists,
                            value2: p2.careerHighAssists
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    // Empty state
                    ContentUnavailableView {
                        Label("Select Players", systemImage: "person.2")
                    } description: {
                        Text("Choose two players above to compare their stats")
                    }
                    .frame(height: 300)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Compare Players")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-select first two players if available
            if player1 == nil && activePlayers.count >= 1 {
                player1 = activePlayers[0]
            }
            if player2 == nil && activePlayers.count >= 2 {
                player2 = activePlayers[1]
            }
        }
    }
}

// MARK: - Player Selector

struct PlayerSelector: View {
    let title: String
    @Binding var selectedPlayer: Person?
    let availablePlayers: [Person]
    let excludePlayer: Person?

    private var filteredPlayers: [Person] {
        availablePlayers.filter { $0.id != excludePlayer?.id }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(filteredPlayers) { player in
                    Button {
                        selectedPlayer = player
                    } label: {
                        HStack {
                            Text("#\(player.jerseyNumber)")
                            Text(player.fullName)
                            if selectedPlayer?.id == player.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    if let player = selectedPlayer {
                        Text("#\(player.jerseyNumber)")
                            .font(.title2.bold())
                        Text(player.firstName)
                            .font(.caption)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.title2)
                        Text("Select")
                            .font(.caption)
                    }
                }
                .frame(width: 80, height: 70)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Comparison Header

struct ComparisonHeader: View {
    let player1: Person
    let player2: Person

    var body: some View {
        HStack {
            VStack {
                Text("#\(player1.jerseyNumber)")
                    .font(.title.bold())
                Text(player1.firstName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.left.arrow.right")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack {
                Text("#\(player2.jerseyNumber)")
                    .font(.title.bold())
                Text(player2.firstName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let label: String
    let value1: Int
    let value2: Int
    var format: String? = nil

    private var value1Double: Double { Double(value1) }
    private var value2Double: Double { Double(value2) }

    init(label: String, value1: Int, value2: Int) {
        self.label = label
        self.value1 = value1
        self.value2 = value2
        self.format = nil
    }

    init(label: String, value1: Double, value2: Double, format: String) {
        self.label = label
        self.value1 = Int(value1 * 10)  // Store as scaled int for comparison
        self.value2 = Int(value2 * 10)
        self.format = format
    }

    private var displayValue1: String {
        if let format = format {
            return String(format: format, Double(value1) / 10.0)
        }
        return "\(value1)"
    }

    private var displayValue2: String {
        if let format = format {
            return String(format: format, Double(value2) / 10.0)
        }
        return "\(value2)"
    }

    private var winner: Int {
        if value1 > value2 { return 1 }
        if value2 > value1 { return 2 }
        return 0
    }

    var body: some View {
        HStack {
            Text(displayValue1)
                .font(.title3.bold())
                .foregroundStyle(winner == 1 ? .green : .primary)
                .frame(maxWidth: .infinity)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100)
                .multilineTextAlignment(.center)

            Text(displayValue2)
                .font(.title3.bold())
                .foregroundStyle(winner == 2 ? .green : .primary)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        PlayerComparisonView()
    }
    .modelContainer(for: Person.self, inMemory: true)
}
