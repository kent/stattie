import Foundation
import SwiftData

/// Legacy persistence shape retained solely as a read-only migration source.
/// New application writes must create `Stat` records through `Game.recordStat`.
@Model
final class ShiftStat {
    private(set) var id: UUID = UUID()
    private(set) var statName: String = ""
    private(set) var pointValue: Int = 0
    private(set) var made: Int = 0
    private(set) var missed: Int = 0
    private(set) var count: Int = 0
    private(set) var timestamp: Date = Date()

    private(set) var shift: Shift?
    private(set) var definition: StatDefinition?

    var total: Int {
        if made > 0 || missed > 0 {
            return made + missed
        }
        return count
    }

    var points: Int {
        made * pointValue
    }

    var displayValue: String {
        if made > 0 || missed > 0 {
            return "\(made)/\(made + missed)"
        }
        return "\(count)"
    }

    var formattedPercentage: String? {
        let attempts = made + missed
        guard attempts > 0 else { return nil }
        let pct = Double(made) / Double(attempts) * 100
        return String(format: "%.0f%%", pct)
    }

    init(
        statName: String = "",
        pointValue: Int = 0,
        made: Int = 0,
        missed: Int = 0,
        count: Int = 0,
        shift: Shift? = nil,
        definition: StatDefinition? = nil
    ) {
        self.id = UUID()
        self.statName = statName
        self.pointValue = pointValue
        self.made = made
        self.missed = missed
        self.count = count
        self.shift = shift
        self.definition = definition
        self.timestamp = Date()
    }
}
