import SwiftUI
import UIKit

// MARK: - Shareable Stats Card

struct ShareableStatsCard: View {
    let playerName: String
    let jerseyNumber: Int
    let stat: String
    let value: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerName)
                        .font(.title2.bold())
                    Text("#\(jerseyNumber)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.title)
                    .foregroundStyle(accentColor)
            }

            Divider()

            // Main stat
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(accentColor)

                Text(stat)
                    .font(.title3.bold())

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Branding
            HStack {
                Image(systemName: "basketball.fill")
                    .foregroundStyle(.orange)
                Text("Tracked with Stattie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 300, height: 350)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10)
    }
}

// MARK: - Game Highlight Card

struct GameHighlightCard: View {
    let playerName: String
    let jerseyNumber: Int
    let opponent: String
    let points: Int
    let rebounds: Int
    let assists: Int
    let gameDate: Date
    var plusMinus: Int? = nil  // Optional plus/minus from shift tracking

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: gameDate)
    }

    private var plusMinusText: String {
        guard let pm = plusMinus else { return "" }
        return pm > 0 ? "+\(pm)" : "\(pm)"
    }

    private var plusMinusColor: Color {
        guard let pm = plusMinus else { return .secondary }
        if pm > 0 { return .green }
        if pm < 0 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerName)
                        .font(.title2.bold())
                    if !opponent.isEmpty {
                        Text("vs \(opponent)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("#\(jerseyNumber)")
                    .font(.title.bold())
                    .foregroundStyle(.accent)
            }

            // Stats grid
            if let pm = plusMinus {
                // 4-column layout with plus/minus
                HStack(spacing: 16) {
                    StatColumn(value: points, label: "PTS", color: .blue)
                    StatColumn(value: rebounds, label: "REB", color: .green)
                    StatColumn(value: assists, label: "AST", color: .orange)
                    PlusMinusColumn(value: pm)
                }
            } else {
                // Standard 3-column layout
                HStack(spacing: 24) {
                    StatColumn(value: points, label: "PTS", color: .blue)
                    StatColumn(value: rebounds, label: "REB", color: .green)
                    StatColumn(value: assists, label: "AST", color: .orange)
                }
            }

            Divider()

            // Date and branding
            HStack {
                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "basketball.fill")
                        .foregroundStyle(.orange)
                    Text("Stattie")
                        .font(.caption.bold())
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8)
    }
}

struct PlusMinusColumn: View {
    let value: Int

    private var displayText: String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private var color: Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(displayText)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
            Text("+/-")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatColumn: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Achievement Share Card

struct AchievementShareCard: View {
    let achievementTitle: String
    let achievementDescription: String
    let icon: String
    let color: Color
    let playerName: String

    var body: some View {
        VStack(spacing: 20) {
            // Trophy icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(color)
            }

            VStack(spacing: 8) {
                Text("Achievement Unlocked!")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(achievementTitle)
                    .font(.title2.bold())

                Text(achievementDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            HStack {
                Text(playerName)
                    .font(.subheadline.bold())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Stattie")
                        .font(.caption.bold())
                }
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 10)
    }
}

// MARK: - Share Image Generator

class ShareImageGenerator {
    @MainActor
    static func generateImage<V: View>(from view: V) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        let view = controller.view

        let targetSize = controller.sizeThatFits(in: CGSize(width: 400, height: 500))
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - Share Button with Image

struct ShareWithImageButton: View {
    let title: String
    let generateCard: () -> AnyView

    @State private var isGenerating = false

    var body: some View {
        Button {
            shareImage()
        } label: {
            if isGenerating {
                ProgressView()
            } else {
                Label(title, systemImage: "square.and.arrow.up")
            }
        }
        .disabled(isGenerating)
    }

    private func shareImage() {
        isGenerating = true

        Task { @MainActor in
            let card = generateCard()
            if let image = ShareImageGenerator.generateImage(from: card) {
                let activityVC = UIActivityViewController(
                    activityItems: [image, "Tracked with Stattie - the easiest way to track game stats! 📊🏀"],
                    applicationActivities: nil
                )

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }
            isGenerating = false
        }
    }
}

// MARK: - Previews

#Preview("Stats Card") {
    ShareableStatsCard(
        playerName: "Jack James",
        jerseyNumber: 23,
        stat: "Points Per Game",
        value: "18.5",
        subtitle: "This Season",
        accentColor: .blue
    )
}

#Preview("Game Highlight") {
    GameHighlightCard(
        playerName: "Jack James",
        jerseyNumber: 23,
        opponent: "Lakers",
        points: 24,
        rebounds: 8,
        assists: 5,
        gameDate: Date(),
        plusMinus: 12
    )
}

#Preview("Game Highlight Without +/-") {
    GameHighlightCard(
        playerName: "Jack James",
        jerseyNumber: 23,
        opponent: "Lakers",
        points: 24,
        rebounds: 8,
        assists: 5,
        gameDate: Date()
    )
}

#Preview("Achievement") {
    AchievementShareCard(
        achievementTitle: "Score Machine",
        achievementDescription: "Score 20+ points in a single game",
        icon: "flame.fill",
        color: .orange,
        playerName: "Jack James"
    )
}
