import Foundation
import SwiftData

@Model
final class Season {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(name: String, startDate: Date = Date(), endDate: Date? = nil, isActive: Bool = true) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = Date()
    }

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if let end = endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: end))"
        } else {
            return "Since \(formatter.string(from: startDate))"
        }
    }
}

// MARK: - Season Manager

class SeasonManager {
    static let shared = SeasonManager()

    private let defaults = UserDefaults.standard
    private let currentSeasonKey = "currentSeasonName"

    var currentSeasonName: String? {
        get { defaults.string(forKey: currentSeasonKey) }
        set { defaults.set(newValue, forKey: currentSeasonKey) }
    }

    // Quick season presets
    static func currentSchoolYear() -> (name: String, start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        // School year typically runs Aug-May
        // If we're in Aug-Dec, current year starts the season
        // If we're in Jan-Jul, previous year started the season
        let startYear = month >= 8 ? year : year - 1
        let endYear = startYear + 1

        var startComponents = DateComponents()
        startComponents.year = startYear
        startComponents.month = 8
        startComponents.day = 1

        var endComponents = DateComponents()
        endComponents.year = endYear
        endComponents.month = 6
        endComponents.day = 30

        let start = calendar.date(from: startComponents) ?? now
        let end = calendar.date(from: endComponents) ?? now

        return (name: "\(startYear)-\(endYear % 100) Season", start: start, end: end)
    }

    static func currentCalendarYear() -> (name: String, start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)

        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = 1
        startComponents.day = 1

        var endComponents = DateComponents()
        endComponents.year = year
        endComponents.month = 12
        endComponents.day = 31

        let start = calendar.date(from: startComponents) ?? now
        let end = calendar.date(from: endComponents) ?? now

        return (name: "\(year)", start: start, end: end)
    }
}
