import SwiftUI
import SwiftData
import StoreKit

struct GameSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    let game: Game

    @Query private var users: [User]
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false
    @AppStorage("completedGamesCount") private var completedGamesCount = 0
    @State private var showingShareSheet = false
    @State private var newAchievements: [AchievementType] = []
    @State private var showingAchievement = false
    @State private var currentAchievementIndex = 0
    @State private var showingInvitePrompt = false
    @State private var showingTeamInvite = false

    private var currentUser: User? { users.first }

    private var motivationalMessage: String {
        let messages = [
            "Great game! Keep tracking! 🏀",
            "Another one in the books! 📊",
            "Stats don't lie - nice work! 💪",
            "Building that highlight reel! 🌟",
            "Every game counts! Keep it up! 🔥"
        ]
        return messages.randomElement() ?? messages[0]
    }

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

    // Plus/minus data from player shifts
    private var hasShiftData: Bool {
        (game.personStats ?? []).contains { !$0.completedShifts.isEmpty }
    }

    private var playerPlusMinusData: [(person: Person, plusMinus: Int, shiftCount: Int, time: String)] {
        (game.personStats ?? [])
            .filter { !$0.completedShifts.isEmpty }
            .compactMap { pgs -> (Person, Int, Int, String)? in
                guard let person = pgs.person else { return nil }
                return (person, pgs.totalPlusMinus, pgs.completedShifts.count, pgs.formattedTotalShiftTime)
            }
            .sorted { $0.1 > $1.1 } // Sort by plus/minus descending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Motivational header
                    Text(motivationalMessage)
                        .font(.headline)
                        .foregroundStyle(.accent)
                        .padding(.bottom, -8)

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

                    // Plus/Minus Section (when shift data available)
                    if hasShiftData {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PLUS/MINUS")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // Header row
                                HStack {
                                    Text("Player")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Shifts")
                                        .frame(width: 50)
                                    Text("Time")
                                        .frame(width: 60)
                                    Text("+/-")
                                        .frame(width: 50)
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemGroupedBackground))

                                ForEach(Array(playerPlusMinusData.enumerated()), id: \.offset) { index, data in
                                    if index > 0 {
                                        Divider()
                                    }
                                    PlusMinusRow(
                                        name: data.person.displayName,
                                        shiftCount: data.shiftCount,
                                        time: data.time,
                                        plusMinus: data.plusMinus
                                    )
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        handleDismiss()
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
            .sheet(isPresented: $showingTeamInvite) {
                inviteSheetContent
            }
            .overlay {
                invitePromptOverlay
            }
            .onAppear(perform: checkInvitePrompt)
        }
    }

    // MARK: - Invite Prompt Views

    /// Get players associated with this game
    private var gamePlayers: [Person] {
        (game.personStats ?? []).compactMap { $0.person }
    }

    /// First player's name for display
    private var firstPlayerName: String {
        gamePlayers.first?.fullName ?? "Player"
    }

    @ViewBuilder
    private var inviteSheetContent: some View {
        TeamInviteView(team: game.team, players: gamePlayers)
    }

    @ViewBuilder
    private var invitePromptOverlay: some View {
        if showingInvitePrompt {
            invitePromptContent
        }
    }

    private var invitePromptContent: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showingInvitePrompt = false
                    }
                }

            PostGameInvitePrompt(
                playerName: firstPlayerName,
                teamName: game.team?.name ?? "My Team",
                onInvite: {
                    showingInvitePrompt = false
                    showingTeamInvite = true
                },
                onDismiss: {
                    withAnimation {
                        showingInvitePrompt = false
                    }
                }
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func checkInvitePrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if PostGameInvitePrompt.shouldShow() {
                withAnimation(.spring()) {
                    showingInvitePrompt = true
                }
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

    private func handleDismiss() {
        // Increment completed games count
        completedGamesCount += 1

        // Update user streak
        if let user = currentUser {
            user.recordGameCompletion(on: game.gameDate)
            try? modelContext.save()

            // Schedule streak reminder if enabled
            NotificationManager.shared.scheduleStreakReminder(currentStreak: user.currentStreak)
        }

        // Track for smart review prompting
        ReviewManager.shared.trackGameCompleted()

        dismiss()
    }

    private func generateShareText() -> String {
        var text = "🏀 Game Stats\n"
        if !game.opponent.isEmpty {
            text += "vs \(game.opponent)\n"
        }
        text += "📊 \(game.totalPoints) Points\n"
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

        // Add plus/minus if shift data exists
        if hasShiftData {
            text += "\nPLUS/MINUS\n"
            for data in playerPlusMinusData {
                let pmText = data.plusMinus > 0 ? "+\(data.plusMinus)" : "\(data.plusMinus)"
                text += "\(data.person.displayName): \(pmText) (\(data.shiftCount) shifts, \(data.time))\n"
            }
        }

        text += "\nTracked with Stattie 📱"

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

struct PlusMinusRow: View {
    let name: String
    let shiftCount: Int
    let time: String
    let plusMinus: Int

    private var plusMinusText: String {
        if plusMinus > 0 { return "+\(plusMinus)" }
        return "\(plusMinus)"
    }

    private var plusMinusColor: Color {
        if plusMinus > 0 { return .green }
        if plusMinus < 0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text("\(shiftCount)")
                .frame(width: 50)
            Text(time)
                .frame(width: 60)
            Text(plusMinusText)
                .frame(width: 50)
                .fontWeight(.bold)
                .foregroundStyle(plusMinusColor)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 12)
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
