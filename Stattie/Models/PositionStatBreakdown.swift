import Foundation

/// Aggregated stats for one recorded shift position (or unspecified legacy shifts).
struct PositionStatTotals: Identifiable, Equatable {
    let position: SoccerPosition?
    let shiftCount: Int
    let duration: TimeInterval
    let plusMinus: Int
    let points: Int
    let made: [String: Int]
    let missed: [String: Int]
    let counts: [String: Int]

    var id: String { position?.rawValue ?? "unspecified" }

    var displayName: String {
        position?.displayName ?? "Unspecified"
    }

    var iconName: String {
        position?.iconName ?? "questionmark.circle"
    }

    var formattedDuration: String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedPlusMinus: String {
        plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
    }

    func count(forName name: String) -> Int {
        counts[name] ?? 0
    }

    func madeCount(forName name: String) -> Int {
        made[name] ?? 0
    }

    func missedCount(forName name: String) -> Int {
        missed[name] ?? 0
    }

    func attempts(forName name: String) -> Int {
        madeCount(forName: name) + missedCount(forName: name)
    }

    func madeString(forName name: String) -> String {
        let madeValue = madeCount(forName: name)
        return "\(madeValue)/\(madeValue + missedCount(forName: name))"
    }
}

enum PositionStatAggregator {
    static func totals(from shifts: [Shift]) -> [PositionStatTotals] {
        let grouped = Dictionary(grouping: shifts) { shift in
            shift.recordedPosition?.rawValue ?? ""
        }

        return grouped.keys.sorted { lhs, rhs in
            if lhs.isEmpty { return false }
            if rhs.isEmpty { return true }
            let leftName = SoccerPosition(rawValue: lhs)?.displayName ?? lhs
            let rightName = SoccerPosition(rawValue: rhs)?.displayName ?? rhs
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
        .compactMap { key in
            guard let group = grouped[key], !group.isEmpty else { return nil }
            return totals(for: group, position: SoccerPosition(rawValue: key))
        }
    }

    static func seasonTotals(from personGameStats: [PersonGameStats]) -> [PositionStatTotals] {
        let shifts = personGameStats
            .filter { $0.game?.isCompleted == true }
            .flatMap { $0.shifts ?? [] }
        return totals(from: shifts)
    }

    static func highlightLines(
        for totals: PositionStatTotals,
        sportName: String?
    ) -> [(title: String, value: String)] {
        if sportName == "Soccer" {
            return soccerHighlights(for: totals)
        }
        if sportName == "Basketball" {
            return basketballHighlights(for: totals)
        }
        if let profile = SportCatalog.profile(named: sportName) {
            return catalogHighlights(for: totals, profile: profile)
        }
        return defaultHighlights(for: totals)
    }

    private static func totals(for shifts: [Shift], position: SoccerPosition?) -> PositionStatTotals {
        var seen = Set<UUID>()
        var made: [String: Int] = [:]
        var missed: [String: Int] = [:]
        var counts: [String: Int] = [:]
        var points = 0

        for shift in shifts {
            for stat in shift.canonicalStats where seen.insert(stat.id).inserted {
                made[stat.statName, default: 0] += stat.made
                missed[stat.statName, default: 0] += stat.missed
                counts[stat.statName, default: 0] += stat.count
                points += stat.points
            }
        }

        return PositionStatTotals(
            position: position,
            shiftCount: shifts.count,
            duration: shifts.reduce(0) { $0 + $1.duration },
            plusMinus: shifts.compactMap(\.plusMinus).reduce(0, +),
            points: points,
            made: made,
            missed: missed,
            counts: counts
        )
    }

    private static func soccerHighlights(for totals: PositionStatTotals) -> [(title: String, value: String)] {
        var lines: [(String, String)] = []
        appendCount(&lines, title: "Goals", value: totals.count(forName: "GOL"))
        if totals.attempts(forName: "SOT") > 0 {
            lines.append(("Shots", totals.madeString(forName: "SOT")))
        }
        appendCount(&lines, title: "Assists", value: totals.count(forName: "AST"))
        appendCount(&lines, title: "Saves", value: totals.count(forName: "SAV"))
        appendCount(&lines, title: "Tackles", value: totals.count(forName: "TKL"))
        appendCount(&lines, title: "Interceptions", value: totals.count(forName: "INT"))
        appendCount(&lines, title: "Passes", value: totals.count(forName: "PAS"))
        return lines
    }

    private static func basketballHighlights(for totals: PositionStatTotals) -> [(title: String, value: String)] {
        var lines: [(String, String)] = []
        if totals.points > 0 {
            lines.append(("Points", "\(totals.points)"))
        }
        let rebounds = totals.count(forName: "DREB") + totals.count(forName: "OREB")
        appendCount(&lines, title: "Rebounds", value: rebounds)
        appendCount(&lines, title: "Assists", value: totals.count(forName: "AST"))
        appendCount(&lines, title: "Steals", value: totals.count(forName: "STL"))
        appendCount(&lines, title: "Turnovers", value: totals.count(forName: "TO"))
        return lines
    }

    private static func catalogHighlights(
        for totals: PositionStatTotals,
        profile: SportProfile
    ) -> [(title: String, value: String)] {
        var lines: [(String, String)] = []
        let specs = profile.highlightShortNames.compactMap { profile.spec(shortName: $0) }
        for spec in specs {
            if spec.hasMadeAndMissed {
                if totals.attempts(forName: spec.shortName) > 0 {
                    lines.append((spec.name, totals.madeString(forName: spec.shortName)))
                }
            } else {
                appendCount(&lines, title: spec.name, value: totals.count(forName: spec.shortName))
            }
        }
        if lines.isEmpty {
            return defaultHighlights(for: totals)
        }
        return lines
    }

    private static func defaultHighlights(for totals: PositionStatTotals) -> [(title: String, value: String)] {
        var lines: [(String, String)] = []
        if totals.points > 0 {
            lines.append(("Points", "\(totals.points)"))
        }
        let namedCounts = totals.counts
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(4)
        for item in namedCounts {
            lines.append((item.key, "\(item.value)"))
        }
        return lines
    }

    private static func appendCount(
        _ lines: inout [(String, String)],
        title: String,
        value: Int
    ) {
        guard value > 0 else { return }
        lines.append((title, "\(value)"))
    }
}
