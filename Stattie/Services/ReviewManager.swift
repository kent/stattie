import Foundation
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class ReviewManager {
    static let shared = ReviewManager()

    private let defaults = UserDefaults.standard

    // Keys
    private let gamesCompletedKey = "reviewGamesCompleted"
    private let lastReviewRequestKey = "lastReviewRequestDate"
    private let reviewRequestCountKey = "reviewRequestCount"

    private var gamesCompleted: Int {
        get { defaults.integer(forKey: gamesCompletedKey) }
        set { defaults.set(newValue, forKey: gamesCompletedKey) }
    }

    private var lastReviewRequest: Date? {
        get { defaults.object(forKey: lastReviewRequestKey) as? Date }
        set { defaults.set(newValue, forKey: lastReviewRequestKey) }
    }

    private var reviewRequestCount: Int {
        get { defaults.integer(forKey: reviewRequestCountKey) }
        set { defaults.set(newValue, forKey: reviewRequestCountKey) }
    }

    // MARK: - Track Events

    func trackGameCompleted() {
        gamesCompleted += 1
        checkForReviewOpportunity()
    }

    func trackAchievementUnlocked() {
        // Great moment for review - user just had a positive experience
        checkForReviewOpportunity(force: true)
    }

    func trackMilestoneReached() {
        checkForReviewOpportunity(force: true)
    }

    // MARK: - Review Logic

    private func checkForReviewOpportunity(force: Bool = false) {
        // Don't spam reviews
        if let lastRequest = lastReviewRequest {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            // Wait at least 60 days between requests
            if daysSinceLastRequest < 60 {
                return
            }
        }

        // Limit total requests
        if reviewRequestCount >= 3 {
            return
        }

        // Trigger points:
        // 1. After 3 completed games (first ask)
        // 2. After 10 completed games (second ask)
        // 3. After achievement unlock (any time)
        // 4. After 25 games (third and final ask)

        let shouldRequest: Bool
        if force {
            shouldRequest = true
        } else {
            switch gamesCompleted {
            case 3, 10, 25:
                shouldRequest = true
            default:
                shouldRequest = false
            }
        }

        if shouldRequest {
            requestReview()
        }
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            lastReviewRequest = Date()
            reviewRequestCount += 1
        }
    }

    // MARK: - Manual Review Link

    static func openAppStoreForReview() {
        let appID = "6758022135"
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}
