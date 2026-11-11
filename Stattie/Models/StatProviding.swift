import Foundation

/// Read-only totals shown by the stat board, from persisted records or an edit draft.
protocol StatTotals {
    var totalPoints: Int { get }
    func totalMade(forName name: String) -> Int
    func totalMissed(forName name: String) -> Int
    func totalCount(forName name: String) -> Int
}

extension StatTotals {
    func madeString(forName name: String) -> String {
        let made = totalMade(forName: name)
        return "\(made)/\(made + totalMissed(forName: name))"
    }

    /// Basketball categories (points, rebounds, assists, steals) with at least ten.
    var doubleDigitCategories: Int {
        [
            totalPoints,
            totalCount(forName: "DREB") + totalCount(forName: "OREB"),
            totalCount(forName: "AST"),
            totalCount(forName: "STL"),
        ].filter { $0 >= 10 }.count
    }
}

/// Shared aggregation for canonical game, player, and shift records.
/// Each model owns attribution and deduplication; all displays use these totals.
protocol StatProviding: StatTotals {
    var canonicalStats: [Stat] { get }
}

extension StatProviding {
    var totalPoints: Int { canonicalStats.reduce(0) { $0 + $1.points } }

    func totalMade(forName name: String) -> Int { total(\.made, named: name) }
    func totalMissed(forName name: String) -> Int { total(\.missed, named: name) }
    func totalCount(forName name: String) -> Int { total(\.count, named: name) }

    private func total(_ keyPath: KeyPath<Stat, Int>, named name: String) -> Int {
        canonicalStats.reduce(0) { total, stat in
            total + (stat.statName == name ? stat[keyPath: keyPath] : 0)
        }
    }
}

extension Game: StatProviding {}
extension PersonGameStats: StatProviding {}
extension Shift: StatProviding {}
