import SwiftUI
import UIKit

// MARK: - Haptic Feedback Manager

class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selection.prepare()
    }

    // MARK: - Standard Haptics

    func lightTap() {
        lightImpact.impactOccurred()
    }

    func mediumTap() {
        mediumImpact.impactOccurred()
    }

    func heavyTap() {
        heavyImpact.impactOccurred()
    }

    func selectionTap() {
        selection.selectionChanged()
    }

    func success() {
        notification.notificationOccurred(.success)
    }

    func warning() {
        notification.notificationOccurred(.warning)
    }

    func error() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Game-Specific Haptics

    func statIncrement() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    func statDecrement() {
        lightImpact.impactOccurred(intensity: 0.4)
    }

    func pointsScored() {
        mediumImpact.impactOccurred()
    }

    func milestoneReached() {
        // Double tap for milestone
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.heavyImpact.impactOccurred()
        }
    }

    func achievementUnlocked() {
        // Triple celebration
        notification.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.heavyImpact.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.notification.notificationOccurred(.success)
        }
    }

    func gameEnded() {
        heavyImpact.impactOccurred()
    }

    func undoAction() {
        notification.notificationOccurred(.warning)
    }
}

// MARK: - Accessibility Labels

struct A11yLabels {
    // Player List
    static func playerRow(name: String, jerseyNumber: Int, gamesCount: Int, ppg: Double) -> String {
        var label = "\(name), number \(jerseyNumber)"
        if gamesCount > 0 {
            label += ", \(gamesCount) games played, averaging \(String(format: "%.1f", ppg)) points per game"
        }
        return label
    }

    static func playerRowHint(hasActiveGame: Bool) -> String {
        if hasActiveGame {
            return "Has active game. Double tap to view player details."
        }
        return "Double tap to view player details and game history."
    }

    // Game Tracking
    static func statButton(name: String, value: Int, isMadeType: Bool) -> String {
        if isMadeType {
            return "\(name) made, current count: \(value). Double tap to increment."
        }
        return "\(name), current count: \(value). Double tap to increment."
    }

    static func statButtonHint(canUndo: Bool) -> String {
        if canUndo {
            return "Triple tap to undo last increment."
        }
        return ""
    }

    // Game Summary
    static func gameSummary(points: Int, opponent: String, date: String) -> String {
        var label = "\(points) points"
        if !opponent.isEmpty {
            label += " against \(opponent)"
        }
        label += " on \(date)"
        return label
    }

    // Stats
    static func statValue(name: String, value: Int, average: Double? = nil) -> String {
        var label = "\(name): \(value)"
        if let avg = average {
            label += ", averaging \(String(format: "%.1f", avg)) per game"
        }
        return label
    }

    // Achievements
    static func achievement(title: String, description: String, isUnlocked: Bool, points: Int) -> String {
        if isUnlocked {
            return "\(title), unlocked. \(description). Worth \(points) points."
        }
        return "\(title), locked. \(description). Worth \(points) points when unlocked."
    }

    // Streaks
    static func streak(days: Int, atRisk: Bool) -> String {
        var label = "\(days) day streak"
        if atRisk {
            label += ". At risk! Track a game today to continue."
        }
        return label
    }
}

// MARK: - View Modifiers

struct AccessibleStatButton: ViewModifier {
    let statName: String
    let value: Int
    let isMadeType: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(A11yLabels.statButton(name: statName, value: value, isMadeType: isMadeType))
            .accessibilityHint("Double tap to add one. Swipe up or down to adjust.")
            .accessibilityAddTraits(.isButton)
    }
}

struct AccessiblePlayerRow: ViewModifier {
    let name: String
    let jerseyNumber: Int
    let gamesCount: Int
    let ppg: Double
    let hasActiveGame: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(A11yLabels.playerRow(name: name, jerseyNumber: jerseyNumber, gamesCount: gamesCount, ppg: ppg))
            .accessibilityHint(A11yLabels.playerRowHint(hasActiveGame: hasActiveGame))
    }
}

extension View {
    func accessibleStatButton(name: String, value: Int, isMadeType: Bool = false) -> some View {
        modifier(AccessibleStatButton(statName: name, value: value, isMadeType: isMadeType))
    }

    func accessiblePlayerRow(name: String, jerseyNumber: Int, gamesCount: Int, ppg: Double, hasActiveGame: Bool) -> some View {
        modifier(AccessiblePlayerRow(name: name, jerseyNumber: jerseyNumber, gamesCount: gamesCount, ppg: ppg, hasActiveGame: hasActiveGame))
    }
}

// MARK: - Dynamic Type Support

struct ScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight

    @Environment(\.sizeCategory) var sizeCategory

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight))
    }

    var scaledSize: CGFloat {
        UIFontMetrics.default.scaledValue(for: size)
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}

// MARK: - Reduce Motion Support

struct ReduceMotionWrapper<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    let reducedAnimation: Animation?
    let content: () -> Content

    var body: some View {
        content()
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

extension View {
    func motionSensitiveAnimation(_ animation: Animation, reduced: Animation? = nil) -> some View {
        ReduceMotionWrapper(animation: animation, reducedAnimation: reduced) {
            self
        }
    }
}
