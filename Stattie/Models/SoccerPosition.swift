import Foundation

/// Soccer positions with display names and categorization
enum SoccerPosition: String, CaseIterable, Codable, Identifiable {
    case goalkeeper = "GK"
    case defender = "DEF"
    case leftBack = "LB"
    case rightBack = "RB"
    case centerBack = "CB"
    case midfielder = "MID"
    case defensiveMidfielder = "CDM"
    case centralMidfielder = "CM"
    case attackingMidfielder = "CAM"
    case leftMidfielder = "LM"
    case rightMidfielder = "RM"
    case forward = "FWD"
    case striker = "ST"
    case leftWing = "LW"
    case rightWing = "RW"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .goalkeeper: return "Goalkeeper"
        case .defender: return "Defender"
        case .leftBack: return "Left Back"
        case .rightBack: return "Right Back"
        case .centerBack: return "Center Back"
        case .midfielder: return "Midfielder"
        case .defensiveMidfielder: return "Defensive Mid"
        case .centralMidfielder: return "Central Mid"
        case .attackingMidfielder: return "Attacking Mid"
        case .leftMidfielder: return "Left Mid"
        case .rightMidfielder: return "Right Mid"
        case .forward: return "Forward"
        case .striker: return "Striker"
        case .leftWing: return "Left Wing"
        case .rightWing: return "Right Wing"
        }
    }

    var shortName: String { rawValue }

    var category: PositionCategory {
        switch self {
        case .goalkeeper:
            return .goalkeeper
        case .defender, .leftBack, .rightBack, .centerBack:
            return .defense
        case .midfielder, .defensiveMidfielder, .centralMidfielder, .attackingMidfielder, .leftMidfielder, .rightMidfielder:
            return .midfield
        case .forward, .striker, .leftWing, .rightWing:
            return .attack
        }
    }

    var iconName: String {
        switch self {
        case .goalkeeper: return "hand.raised.fill"
        case .defender, .leftBack, .rightBack, .centerBack: return "shield.fill"
        case .midfielder, .defensiveMidfielder, .centralMidfielder, .attackingMidfielder, .leftMidfielder, .rightMidfielder: return "figure.run"
        case .forward, .striker, .leftWing, .rightWing: return "scope"
        }
    }

    enum PositionCategory: String, CaseIterable {
        case goalkeeper = "Goalkeeper"
        case defense = "Defense"
        case midfield = "Midfield"
        case attack = "Attack"

        var positions: [SoccerPosition] {
            SoccerPosition.allCases.filter { $0.category == self }
        }
    }
}

/// Represents a position assignment with a percentage of playing time
struct PositionAssignment: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var position: SoccerPosition
    var percentage: Int  // 0-100

    init(position: SoccerPosition, percentage: Int = 100) {
        self.position = position
        self.percentage = min(100, max(0, percentage))
    }

    var displayText: String {
        if percentage == 100 {
            return position.displayName
        } else {
            return "\(position.displayName) (\(percentage)%)"
        }
    }
}

/// A collection of position assignments that should sum to 100%
struct PositionAssignments: Codable, Equatable {
    var assignments: [PositionAssignment]

    init(assignments: [PositionAssignment] = []) {
        self.assignments = assignments
    }

    /// Creates a single position at 100%
    init(singlePosition: SoccerPosition) {
        self.assignments = [PositionAssignment(position: singlePosition, percentage: 100)]
    }

    /// Total percentage (should be 100 for a valid configuration)
    var totalPercentage: Int {
        assignments.reduce(0) { $0 + $1.percentage }
    }

    var isValid: Bool {
        !assignments.isEmpty && totalPercentage == 100
    }

    var isEmpty: Bool {
        assignments.isEmpty
    }

    /// Display string for all positions
    var displayText: String {
        if assignments.isEmpty {
            return ""
        }
        if assignments.count == 1 && assignments[0].percentage == 100 {
            return assignments[0].position.displayName
        }
        return assignments.map { $0.displayText }.joined(separator: " / ")
    }

    /// Short display with abbreviations
    var shortDisplayText: String {
        if assignments.isEmpty {
            return ""
        }
        if assignments.count == 1 && assignments[0].percentage == 100 {
            return assignments[0].position.shortName
        }
        return assignments.map { "\($0.position.shortName) \($0.percentage)%" }.joined(separator: " / ")
    }

    /// Primary position (highest percentage)
    var primaryPosition: SoccerPosition? {
        assignments.max(by: { $0.percentage < $1.percentage })?.position
    }

    /// Check if this is a goalie (any percentage as goalkeeper)
    var includesGoalkeeper: Bool {
        assignments.contains { $0.position == .goalkeeper }
    }

    mutating func addPosition(_ position: SoccerPosition, percentage: Int) {
        // Remove if already exists
        assignments.removeAll { $0.position == position }
        assignments.append(PositionAssignment(position: position, percentage: percentage))
    }

    mutating func removePosition(_ position: SoccerPosition) {
        assignments.removeAll { $0.position == position }
    }

    mutating func updatePercentage(for position: SoccerPosition, to percentage: Int) {
        if let index = assignments.firstIndex(where: { $0.position == position }) {
            assignments[index].percentage = min(100, max(0, percentage))
        }
    }

    /// Normalize percentages to sum to 100
    mutating func normalize() {
        guard !assignments.isEmpty else { return }
        let total = totalPercentage
        guard total > 0 else { return }

        // Simple proportional scaling
        let scale = 100.0 / Double(total)
        var sum = 0
        for i in 0..<(assignments.count - 1) {
            let scaled = Int(round(Double(assignments[i].percentage) * scale))
            assignments[i].percentage = scaled
            sum += scaled
        }
        // Last one gets remainder to ensure exactly 100
        assignments[assignments.count - 1].percentage = 100 - sum
    }
}

// MARK: - JSON Encoding/Decoding helpers for Person model

extension PositionAssignments {
    /// Encode to JSON string for storage
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode from JSON string
    static func fromJSON(_ json: String?) -> PositionAssignments {
        guard let json = json,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PositionAssignments.self, from: data) else {
            return PositionAssignments()
        }
        return decoded
    }
}
