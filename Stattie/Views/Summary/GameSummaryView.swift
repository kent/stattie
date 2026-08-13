import SwiftUI
import SwiftData
import StoreKit

struct GameSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let game: Game

    @Query private var users: [User]
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false
    @AppStorage("completedGamesCount") private var completedGamesCount = 0
    @State private var showingShareSheet = false
    @State private var newAchievements: [AchievementType] = []
    @State private var showingAchievement = false
    @State private var currentAchievementIndex = 0

    private var currentUser: User? { users.resolvedCurrentUser }

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

    private struct ShootingStatConfig: Identifiable {
        let id: String
        let title: String
        let pointValue: Int
    }

    private struct CountStatConfig: Identifiable {
        let id: String
        let title: String
    }

    private var isSoccer: Bool {
        game.sport?.name == "Soccer"
    }

    private var summaryPrimaryValue: Int {
        isSoccer ? game.totalCount(forName: "GOL") : game.totalPoints
    }

    private var summaryPrimaryLabel: String {
        isSoccer ? "Total Goals" : "Total Points"
    }

    private var shootingStatConfigs: [ShootingStatConfig] {
        if isSoccer {
            return [ShootingStatConfig(id: "SOT", title: "Shots On Target", pointValue: 0)]
        }

        return [
            ShootingStatConfig(id: "2PT", title: "2-Pointers", pointValue: 2),
            ShootingStatConfig(id: "3PT", title: "3-Pointers", pointValue: 3),
            ShootingStatConfig(id: "FT", title: "Free Throws", pointValue: 1),
        ]
    }

    private var countStatConfigs: [CountStatConfig] {
        if isSoccer {
            return [
                CountStatConfig(id: "GOL", title: "Goals"),
                CountStatConfig(id: "AST", title: "Assists"),
                CountStatConfig(id: "SAV", title: "Saves"),
                CountStatConfig(id: "TKL", title: "Tackles"),
                CountStatConfig(id: "INT", title: "Interceptions"),
                CountStatConfig(id: "PAS", title: "Passes"),
                CountStatConfig(id: "CRN", title: "Corners"),
                CountStatConfig(id: "FLS", title: "Fouls"),
                CountStatConfig(id: "YC", title: "Yellow Cards"),
                CountStatConfig(id: "RC", title: "Red Cards"),
            ]
        }

        return [
            CountStatConfig(id: "DREB", title: "Defensive Rebounds"),
            CountStatConfig(id: "OREB", title: "Offensive Rebounds"),
            CountStatConfig(id: "AST", title: "Assists"),
            CountStatConfig(id: "STL", title: "Steals"),
            CountStatConfig(id: "PF", title: "Fouls"),
            CountStatConfig(id: "TO", title: "Turnovers"),
            CountStatConfig(id: "MD", title: "Missed Drive"),
            CountStatConfig(id: "SD", title: "Successful Drive"),
            CountStatConfig(id: "BPO", title: "Bad Offense"),
            CountStatConfig(id: "BPD", title: "Bad Defense"),
            CountStatConfig(id: "GPO", title: "Great Offense"),
            CountStatConfig(id: "GPD", title: "Great Defense"),
        ]
    }

    private var totalRebounds: Int {
        game.totalCount(forName: "DREB") + game.totalCount(forName: "OREB")
    }

    private var hasShootingData: Bool {
        shootingStatConfigs.contains { config in
            let attempts = game.totalMade(forName: config.id) + game.totalMissed(forName: config.id)
            return attempts > 0
        }
    }

    private var allStatLines: [(title: String, value: String)] {
        var lines: [(String, String)] = []

        for config in countStatConfigs {
            let value = game.totalCount(forName: config.id)
            if value > 0 {
                lines.append((config.title, "\(value)"))
            }
        }

        return lines
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

                        Text("\(summaryPrimaryValue)")
                            .scaledFont(size: 72, weight: .bold, relativeTo: .largeTitle)
                            .foregroundStyle(.blue)

                        Text(summaryPrimaryLabel)
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
                    if hasShootingData {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SHOOTING")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // The compact table header is omitted at accessibility
                                // sizes; each row supplies full, wrapping labels instead.
                                if !dynamicTypeSize.isAccessibilitySize {
                                    HStack {
                                        Text("Stat")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Made").frame(width: 50)
                                        Text("Att").frame(width: 50)
                                        Text("Pct").frame(width: 50)
                                        Text("Pts").frame(width: 50)
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                }

                                ForEach(Array(shootingStatConfigs.enumerated()), id: \.element.id) { index, config in
                                    if index > 0 {
                                        Divider()
                                    }

                                    StatRow(
                                        name: config.title,
                                        made: game.totalMade(forName: config.id),
                                        attempts: game.totalMade(forName: config.id) + game.totalMissed(forName: config.id),
                                        pointValue: config.pointValue
                                    )
                                }
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

                        if isSoccer {
                            HStack(spacing: 12) {
                                StatBox(
                                    title: "Goals",
                                    value: game.totalCount(forName: "GOL"),
                                    detail: nil
                                )

                                StatBox(
                                    title: "Assists",
                                    value: game.totalCount(forName: "AST"),
                                    detail: nil
                                )

                                StatBox(
                                    title: "Saves",
                                    value: game.totalCount(forName: "SAV"),
                                    detail: nil
                                )

                                StatBox(
                                    title: "Tackles",
                                    value: game.totalCount(forName: "TKL"),
                                    detail: nil
                                )
                            }
                        } else {
                            HStack(spacing: 12) {
                                StatBox(
                                    title: "Rebounds",
                                    value: totalRebounds,
                                    detail: "D: \(game.totalCount(forName: "DREB")) / O: \(game.totalCount(forName: "OREB"))"
                                )

                                StatBox(
                                    title: "Assists",
                                    value: game.totalCount(forName: "AST"),
                                    detail: nil
                                )

                                StatBox(
                                    title: "Steals",
                                    value: game.totalCount(forName: "STL"),
                                    detail: nil
                                )

                                StatBox(
                                    title: "Turnovers",
                                    value: game.totalCount(forName: "TO"),
                                    detail: nil
                                )
                            }
                        }
                    }

                    if !allStatLines.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ALL STATS")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(Array(allStatLines.enumerated()), id: \.offset) { index, line in
                                    if index > 0 {
                                        Divider()
                                    }

                                    HStack {
                                        Text(line.title)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(line.value)
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                if !dynamicTypeSize.isAccessibilitySize {
                                    HStack {
                                        Text("Player")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Shifts").frame(width: 50)
                                        Text("Time").frame(width: 60)
                                        Text("+/-").frame(width: 50)
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                }

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
        var text = isSoccer ? "⚽ Game Stats\n" : "🏀 Game Stats\n"
        if !game.opponent.isEmpty {
            text += "vs \(game.opponent)\n"
        }
        if isSoccer {
            text += "📊 \(summaryPrimaryValue) Goals\n"
        } else {
            text += "📊 \(summaryPrimaryValue) Points\n"
        }
        text += "\(game.formattedDate)\n\n"

        if hasShootingData {
            text += "SHOOTING\n"
            for config in shootingStatConfigs {
                let made = game.totalMade(forName: config.id)
                let attempts = made + game.totalMissed(forName: config.id)
                if attempts > 0 {
                    text += "\(config.title): \(made)/\(attempts)\n"
                }
            }
            text += "\n"
        }

        if !allStatLines.isEmpty {
            text += "ALL STATS\n"
            for line in allStatLines {
                text += "\(line.title): \(line.value)\n"
            }
        }

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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(.headline)
                LabeledContent("Made", value: "\(made)")
                LabeledContent("Attempts", value: "\(attempts)")
                LabeledContent("Percentage", value: percentage)
                LabeledContent("Points", value: "\(points)")
                    .fontWeight(.semibold)
            }
            .padding()
        } else {
            HStack {
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(made)").frame(width: 50)
                Text("\(attempts)").frame(width: 50)
                Text(percentage).frame(width: 50)
                Text("\(points)")
                    .frame(width: 50)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(.headline)
                LabeledContent("Shifts", value: "\(shiftCount)")
                LabeledContent("Time", value: time)
                LabeledContent("Plus/minus") {
                    Text(plusMinusText)
                        .fontWeight(.bold)
                        .foregroundStyle(plusMinusColor)
                }
            }
            .padding()
        } else {
            HStack {
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(shiftCount)").frame(width: 50)
                Text(time).frame(width: 60)
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
