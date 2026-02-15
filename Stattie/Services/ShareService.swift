import SwiftUI

final class ShareService {
    static let shared = ShareService()

    private init() {}

    func generateTextSummary(for game: Game) -> String {
        var lines: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        lines.append("GAME SUMMARY")
        lines.append(String(repeating: "=", count: 40))

        if !game.opponent.isEmpty {
            lines.append("vs \(game.opponent)")
        }

        lines.append(dateFormatter.string(from: game.gameDate))

        if !game.location.isEmpty {
            lines.append("Location: \(game.location)")
        }

        lines.append("")
        lines.append("FINAL SCORE: \(game.totalPoints) points")
        lines.append(String(repeating: "-", count: 40))

        let personStats = (game.personStats ?? []).sorted {
            ($0.person?.jerseyNumber ?? 0) < ($1.person?.jerseyNumber ?? 0)
        }

        for pgs in personStats {
            guard let person = pgs.person else { continue }
            let stats = pgs.stats ?? []
            if stats.isEmpty || stats.allSatisfy({ $0.total == 0 }) { continue }

            lines.append("")
            lines.append("\(person.displayName)")
            lines.append("  Points: \(pgs.totalPoints)")

            let shootingStats = stats.filter { $0.definition?.hasMadeAndMissed == true && $0.total > 0 }
            for stat in shootingStats.sorted(by: { ($0.definition?.sortOrder ?? 0) < ($1.definition?.sortOrder ?? 0) }) {
                if let def = stat.definition {
                    let pctString = stat.formattedPercentage.map { " (\($0))" } ?? ""
                    lines.append("  \(def.shortName): \(stat.made)/\(stat.made + stat.missed)\(pctString)")
                }
            }

            let countStats = stats.filter { $0.definition?.hasMadeAndMissed == false && $0.count > 0 }
            for stat in countStats.sorted(by: { ($0.definition?.sortOrder ?? 0) < ($1.definition?.sortOrder ?? 0) }) {
                if let def = stat.definition {
                    lines.append("  \(def.shortName): \(stat.count)")
                }
            }
        }

        if !game.notes.isEmpty {
            lines.append("")
            lines.append("Notes: \(game.notes)")
        }

        lines.append("")
        lines.append("Tracked with Stattie")

        return lines.joined(separator: "\n")
    }

    @MainActor
    func share(game: Game, from view: UIView? = nil) {
        let text = generateTextSummary(for: game)
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view ?? rootVC.view
                popover.sourceRect = view?.bounds ?? CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}
