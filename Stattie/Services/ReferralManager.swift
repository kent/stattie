import Foundation
import SwiftUI
import UIKit

class ReferralManager: ObservableObject {
    static let shared = ReferralManager()

    private let defaults = UserDefaults.standard

    // Keys
    private let referralCountKey = "referralShareCount"
    private let lastReferralDateKey = "lastReferralShareDate"

    @Published var referralCount: Int {
        didSet { defaults.set(referralCount, forKey: referralCountKey) }
    }

    var lastReferralDate: Date? {
        get { defaults.object(forKey: lastReferralDateKey) as? Date }
        set { defaults.set(newValue, forKey: lastReferralDateKey) }
    }

    init() {
        referralCount = defaults.integer(forKey: referralCountKey)
    }

    // MARK: - Referral Links

    var referralMessage: String {
        """
        I'm using Stattie to track game stats for my players - it's amazing! 🏀📊

        One-tap stat tracking, performance trends, and easy sharing with family & coaches.

        Download free: https://apps.apple.com/app/stattie/id0
        """
    }

    var shortReferralMessage: String {
        "Track game stats the easy way! Download Stattie: https://apps.apple.com/app/stattie/id0 🏀"
    }

    // MARK: - Share Actions

    func shareReferral() {
        let activityVC = UIActivityViewController(
            activityItems: [referralMessage],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true) { [weak self] in
                self?.trackReferral()
            }
        }
    }

    func trackReferral() {
        referralCount += 1
        lastReferralDate = Date()

        // Check for sharing achievement
        if referralCount == 1 {
            _ = AchievementManager.shared.unlock(.sharedPlayer)
        }
    }

    // MARK: - Referral Prompts

    var shouldShowReferralPrompt: Bool {
        // Show after user has some engagement
        let gamesTracked = defaults.integer(forKey: "completedGamesCount")

        // Don't show too frequently
        if let lastDate = lastReferralDate {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysSince < 14 {
                return false
            }
        }

        // Show after 5 games, then every 14 days
        return gamesTracked >= 5
    }
}

// MARK: - Referral Card View

struct ReferralCard: View {
    @StateObject private var referralManager = ReferralManager.shared
    @State private var showCard = true

    var body: some View {
        if showCard && referralManager.shouldShowReferralPrompt {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share the Love!")
                            .font(.headline)
                        Text("Help other parents discover Stattie")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            showCard = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    referralManager.shareReferral()
                    withAnimation {
                        showCard = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Invite Friends & Family")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Invite Friends Section

struct InviteFriendsSection: View {
    @StateObject private var referralManager = ReferralManager.shared

    var body: some View {
        Section {
            Button {
                referralManager.shareReferral()
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite Friends & Family")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Share Stattie with other parents & coaches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if referralManager.referralCount > 0 {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                    Text("You've shared Stattie \(referralManager.referralCount) time\(referralManager.referralCount == 1 ? "" : "s")!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Spread the Word")
        }
    }
}
