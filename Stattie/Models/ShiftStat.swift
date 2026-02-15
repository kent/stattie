import Foundation
import SwiftData

@Model
final class ShiftStat {
    var id: UUID = UUID()
    var statName: String = ""
    var pointValue: Int = 0
    var made: Int = 0
    var missed: Int = 0
    var count: Int = 0
    var timestamp: Date = Date()

    var shift: Shift?
    var definition: StatDefinition?

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
