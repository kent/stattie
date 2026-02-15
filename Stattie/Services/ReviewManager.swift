import Foundation
import StoreKit
import SwiftUI
import UIKit

class ReviewManager {
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
            if daysSinceLastRequest < 60 && !force {
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
        // Use EnvironmentValues requestReview is the modern way
        // But for simplicity we'll use the older scene-based approach
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            lastReviewRequest = Date()
            reviewRequestCount += 1
        }
    }

    // MARK: - Manual Review Link

    static func openAppStoreForReview() {
        // Replace with actual App ID when published
        let appId = "id0" // Placeholder
        if let url = URL(string: "https://apps.apple.com/app/\(appId)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Review Prompt View

struct ReviewPromptCard: View {
    @State private var showingCard = true

    var body: some View {
        if showingCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Enjoying Stattie?")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation {
                            showingCard = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Your review helps other parents and coaches discover Stattie!")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        ReviewManager.openAppStoreForReview()
                        withAnimation {
                            showingCard = false
                        }
                    } label: {
                        Text("Rate on App Store")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        withAnimation {
                            showingCard = false
                        }
                    } label: {
                        Text("Not Now")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
