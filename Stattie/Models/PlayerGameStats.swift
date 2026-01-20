import Foundation
import SwiftData

@Model
final class PlayerGameStats {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    var player: Player?
    var game: Game?

    @Relationship(deleteRule: .cascade, inverse: \Stat.playerGameStats)
    var stats: [Stat]? = []

    var totalPoints: Int {
        (stats ?? []).reduce(0) { $0 + $1.points }
    }

    var totalRebounds: Int {
        let drebs = (stats ?? []).first(where: { $0.statName == "DREB" })?.count ?? 0
        let orebs = (stats ?? []).first(where: { $0.statName == "OREB" })?.count ?? 0
        return drebs + orebs
    }

    var totalSteals: Int {
        (stats ?? []).first(where: { $0.statName == "STL" })?.count ?? 0
    }

    var totalAssists: Int {
        (stats ?? []).first(where: { $0.statName == "AST" })?.count ?? 0
    }

    var totalFouls: Int {
        (stats ?? []).first(where: { $0.statName == "PF" })?.count ?? 0
    }

    init(player: Player? = nil, game: Game? = nil) {
        self.id = UUID()
        self.player = player
        self.game = game
        self.createdAt = Date()
    }

    func stat(forName name: String) -> Stat? {
        (stats ?? []).first { $0.statName == name }
    }
}
