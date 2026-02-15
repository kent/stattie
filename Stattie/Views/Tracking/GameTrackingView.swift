import SwiftUI
import SwiftData
import UIKit

// MARK: - Undo Action

enum UndoActionType {
    case made(statName: String, points: Int)
    case missed(statName: String, points: Int)
    case count(statName: String)
}

struct UndoAction {
    let type: UndoActionType
    let timestamp: Date

    var description: String {
        switch type {
        case .made(let name, _): return "\(name) made"
        case .missed(let name, _): return "\(name) miss"
        case .count(let name): return name
        }
    }
}

struct GameTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    @State private var showingEndGameAlert = false
    @State private var showingSummary = false
    @State private var showMilestoneAnimation = false
    @State private var milestoneText = ""
    @State private var previousDoubleDigits = 0

    // Game timer
    @State private var gameElapsedTime: TimeInterval = 0
    @State private var timerRunning = false
    @State private var gameStartTime: Date?

    // Undo support
    @State private var lastAction: UndoAction?
    @State private var showingUndoToast = false

    // Haptic feedback generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private var isSoccer: Bool {
        game.sport?.name == "Soccer"
    }

    var totalPoints: Int {
        game.totalPoints
    }

    // Basketball stats
    var totalRebounds: Int {
        (game.stat(named: "DREB")?.count ?? 0) + (game.stat(named: "OREB")?.count ?? 0)
    }

    var totalAssists: Int {
        game.stat(named: "AST")?.count ?? 0
    }

    var totalSteals: Int {
        game.stat(named: "STL")?.count ?? 0
    }

    // Soccer stats
    var totalGoals: Int {
        game.stat(named: "GOL")?.count ?? 0
    }

    var totalSaves: Int {
        game.stat(named: "SAV")?.count ?? 0
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
        !isSoccer && doubleDigitCategories >= 2
    }

    var hasTripleDouble: Bool {
        !isSoccer && doubleDigitCategories >= 3
    }

    private var formattedTime: String {
        let minutes = Int(gameElapsedTime) / 60
        let seconds = Int(gameElapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Timer bar
                HStack {
                    // Timer display
                    Button {
                        toggleTimer()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(formattedTime)
                                .font(.system(.title2, design: .monospaced, weight: .semibold))
                        }
                        .foregroundStyle(timerRunning ? .green : .secondary)
                    }

                    Spacer()

                    // Undo button
                    if lastAction != nil {
                        Button {
                            performUndo()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)

                if isSoccer {
                    soccerTrackingView
                } else {
                    basketballTrackingView
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
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if timerRunning {
                    gameElapsedTime += 1
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
            .overlay {
                if showMilestoneAnimation {
                    MilestoneOverlay(text: milestoneText)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Basketball View

    private var basketballTrackingView: some View {
        VStack(spacing: 10) {
            // Score display
            HStack {
                Text("\(totalPoints)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.blue)
                Text("PTS")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Achievements inline
                if hasTripleDouble {
                    Label("Triple Double", systemImage: "star.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                } else if hasDoubleDouble {
                    Label("Double Double", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)

            // Shooting buttons - 3 across
            HStack(spacing: 10) {
                FlexStatButton(title: "2 PTS", subtitle: madeString("2PT"), color: .blue) {
                    recordMade("2PT", points: 2)
                }
                FlexStatButton(title: "3 PTS", subtitle: madeString("3PT"), color: .purple) {
                    recordMade("3PT", points: 3)
                }
                FlexStatButton(title: "FT", subtitle: madeString("FT"), color: .orange) {
                    recordMade("FT", points: 1)
                }
            }
            .padding(.horizontal)

            // Miss buttons
            HStack(spacing: 8) {
                MissButton(title: "2PT Miss") { recordMiss("2PT", points: 2) }
                MissButton(title: "3PT Miss") { recordMiss("3PT", points: 3) }
                MissButton(title: "FT Miss") { recordMiss("FT", points: 1) }
            }
            .padding(.horizontal)

            // Other stats - 3 columns, 2 rows
            HStack(spacing: 10) {
                FlexStatButton(title: "D-REB", subtitle: countString("DREB"), color: .green) {
                    recordCount("DREB")
                }
                FlexStatButton(title: "O-REB", subtitle: countString("OREB"), color: .teal) {
                    recordCount("OREB")
                }
                FlexStatButton(title: "STEAL", subtitle: countString("STL"), color: .indigo) {
                    recordCount("STL")
                }
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                FlexStatButton(title: "ASSIST", subtitle: countString("AST"), color: .mint) {
                    recordCount("AST")
                }
                FlexStatButton(title: "DRIVE", subtitle: countString("DRV"), color: .cyan) {
                    recordCount("DRV")
                }
                FlexStatButton(title: "FOUL", subtitle: countString("PF"), color: .red) {
                    recordCount("PF")
                }
            }
            .padding(.horizontal)

            FlexStatButton(title: "GREAT PLAY", subtitle: countString("GP"), color: .yellow) {
                recordCount("GP")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Soccer View

    private var soccerTrackingView: some View {
        VStack(spacing: 10) {
            // Goal display
            HStack {
                Text("\(totalGoals)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.green)
                Text("GOALS")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if totalSaves > 0 {
                    VStack(alignment: .trailing) {
                        Text("\(totalSaves)")
                            .font(.title.bold())
                            .foregroundStyle(.blue)
                        Text("Saves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            // Scoring stats
            HStack(spacing: 10) {
                FlexStatButton(title: "GOAL", subtitle: countString("GOL"), color: .green) {
                    recordCount("GOL")
                }
                FlexStatButton(title: "SHOT", subtitle: madeString("SOT"), color: .teal) {
                    recordMade("SOT", points: 0)
                }
                FlexStatButton(title: "ASSIST", subtitle: countString("AST"), color: .mint) {
                    recordCount("AST")
                }
            }
            .padding(.horizontal)

            // Miss button for shots
            HStack(spacing: 8) {
                MissButton(title: "Shot Off Target") { recordMiss("SOT", points: 0) }
            }
            .padding(.horizontal)

            // Defense stats
            HStack(spacing: 10) {
                FlexStatButton(title: "SAVE", subtitle: countString("SAV"), color: .blue) {
                    recordCount("SAV")
                }
                FlexStatButton(title: "TACKLE", subtitle: countString("TKL"), color: .indigo) {
                    recordCount("TKL")
                }
                FlexStatButton(title: "INT", subtitle: countString("INT"), color: .purple) {
                    recordCount("INT")
                }
            }
            .padding(.horizontal)

            // Possession and other stats
            HStack(spacing: 10) {
                FlexStatButton(title: "PASS", subtitle: countString("PAS"), color: .cyan) {
                    recordCount("PAS")
                }
                FlexStatButton(title: "CORNER", subtitle: countString("CRN"), color: .orange) {
                    recordCount("CRN")
                }
                FlexStatButton(title: "FOUL", subtitle: countString("FLS"), color: .red) {
                    recordCount("FLS")
                }
            }
            .padding(.horizontal)

            // Cards
            HStack(spacing: 10) {
                FlexStatButton(title: "YELLOW", subtitle: countString("YC"), color: .yellow) {
                    recordCount("YC")
                }
                FlexStatButton(title: "RED", subtitle: countString("RC"), color: .red) {
                    recordCount("RC")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Timer

    private func toggleTimer() {
        timerRunning.toggle()
        if timerRunning && gameStartTime == nil {
            gameStartTime = Date()
        }
        impactLight.impactOccurred()
    }

    // MARK: - Undo

    private func performUndo() {
        guard let action = lastAction else { return }

        impactMedium.impactOccurred()

        switch action.type {
        case .made(let name, let points):
            if let stat = game.stat(named: name), stat.made > 0 {
                stat.made -= 1
                try? modelContext.save()
            }
        case .missed(let name, _):
            if let stat = game.stat(named: name), stat.missed > 0 {
                stat.missed -= 1
                try? modelContext.save()
            }
        case .count(let name):
            if let stat = game.stat(named: name), stat.count > 0 {
                stat.count -= 1
                try? modelContext.save()
            }
        }

        lastAction = nil

        // Show undo confirmation
        withAnimation {
            showingUndoToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showingUndoToast = false
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
        impactMedium.impactOccurred()
        let oldDoubleDigits = doubleDigitCategories
        let stat = getOrCreateStat(name, points: points)
        stat.made += 1
        stat.timestamp = Date()
        try? modelContext.save()

        // Save for undo
        lastAction = UndoAction(type: .made(statName: name, points: points), timestamp: Date())

        checkMilestones(oldDoubleDigits: oldDoubleDigits)
    }

    private func recordMiss(_ name: String, points: Int) {
        impactLight.impactOccurred()
        let stat = getOrCreateStat(name, points: points)
        stat.missed += 1
        stat.timestamp = Date()
        try? modelContext.save()

        // Save for undo
        lastAction = UndoAction(type: .missed(statName: name, points: points), timestamp: Date())
    }

    private func recordCount(_ name: String) {
        impactMedium.impactOccurred()
        let oldDoubleDigits = doubleDigitCategories
        let oldGoals = totalGoals
        let stat = getOrCreateStat(name, points: 0)
        stat.count += 1
        stat.timestamp = Date()
        try? modelContext.save()

        // Save for undo
        lastAction = UndoAction(type: .count(statName: name), timestamp: Date())

        checkMilestones(oldDoubleDigits: oldDoubleDigits)
        checkSoccerMilestones(oldGoals: oldGoals, statName: name)
    }

    private func checkMilestones(oldDoubleDigits: Int) {
        let newDoubleDigits = doubleDigitCategories

        // Check for new double-double or triple-double (basketball)
        if newDoubleDigits >= 2 && oldDoubleDigits < 2 {
            celebrateMilestone("Double Double! 🔥")
        } else if newDoubleDigits >= 3 && oldDoubleDigits < 3 {
            celebrateMilestone("Triple Double! 🌟")
        }
    }

    private func checkSoccerMilestones(oldGoals: Int, statName: String) {
        guard isSoccer else { return }

        // Hat trick - 3 goals
        if statName == "GOL" && oldGoals == 2 && totalGoals == 3 {
            celebrateMilestone("Hat Trick! ⚽️⚽️⚽️")
        }
        // Poker - 4 goals
        else if statName == "GOL" && oldGoals == 3 && totalGoals == 4 {
            celebrateMilestone("Poker! 🃏⚽️")
        }
    }

    private func celebrateMilestone(_ text: String) {
        impactHeavy.impactOccurred()
        notificationFeedback.notificationOccurred(.success)
        milestoneText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showMilestoneAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showMilestoneAnimation = false
            }
        }
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

struct FlexStatButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.headline)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel("\(title), current: \(subtitle)")
        .accessibilityHint("Double tap to record")
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
        .accessibilityLabel("Record \(title)")
        .accessibilityHint("Double tap to record a miss")
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

struct MilestoneOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 20)

                Text(text)
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
}

#Preview {
    GameTrackingView(game: Game(opponent: "Lakers"))
        .modelContainer(for: [Game.self, Stat.self], inMemory: true)
}
