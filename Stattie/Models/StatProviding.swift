import Foundation

/// Shared aggregation for canonical game, player, and shift records.
/// Each model owns attribution and deduplication; all displays use these totals.
protocol StatProviding {
    var canonicalStats: [Stat] { get }
}

extension StatProviding {
    var totalPoints: Int { canonicalStats.reduce(0) { $0 + $1.points } }

    func totalMade(forName name: String) -> Int { total(\.made, named: name) }
    func totalMissed(forName name: String) -> Int { total(\.missed, named: name) }
    func totalCount(forName name: String) -> Int { total(\.count, named: name) }

    func madeString(forName name: String) -> String {
        let records = canonicalStats.filter { $0.statName == name }
        let made = records.reduce(0) { $0 + $1.made }
        let missed = records.reduce(0) { $0 + $1.missed }
        return "\(made)/\(made + missed)"
    }

    private func total(_ keyPath: KeyPath<Stat, Int>, named name: String) -> Int {
        canonicalStats.reduce(0) { total, stat in
            total + (stat.statName == name ? stat[keyPath: keyPath] : 0)
        }
    }
}

extension Game: StatProviding {}
extension PersonGameStats: StatProviding {}
extension Shift: StatProviding {}
