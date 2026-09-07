import Foundation

struct TrackingClock {
    private var accumulated: TimeInterval = 0
    private var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        accumulated + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    mutating func start(at date: Date = Date()) {
        guard startedAt == nil else { return }
        startedAt = date
    }

    mutating func pause(at date: Date = Date()) {
        accumulated = elapsed(at: date)
        startedAt = nil
    }
}
