import Foundation
import SwiftData

@Model
final class Shift {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var shiftNumber: Int = 1
    var createdAt: Date = Date()

    var personGameStats: PersonGameStats?

    @Relationship(deleteRule: .cascade, inverse: \ShiftStat.shift)
    var stats: [ShiftStat]? = []

    var isActive: Bool {
        endTime == nil
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Stat Aggregation

    var totalPoints: Int {
        (stats ?? []).reduce(0) { $0 + $1.points }
    }

    func statValue(forName name: String) -> ShiftStat? {
        (stats ?? []).first { $0.statName == name }
    }

    func totalMade(forName name: String) -> Int {
        statValue(forName: name)?.made ?? 0
    }

    func totalMissed(forName name: String) -> Int {
        statValue(forName: name)?.missed ?? 0
    }

    func totalCount(forName name: String) -> Int {
        statValue(forName: name)?.count ?? 0
    }

    init(
        shiftNumber: Int = 1,
        personGameStats: PersonGameStats? = nil
    ) {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.shiftNumber = shiftNumber
        self.personGameStats = personGameStats
        self.createdAt = Date()
    }

    func endShift() {
        if endTime == nil {
            endTime = Date()
        }
    }
}
