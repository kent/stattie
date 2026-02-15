import SwiftUI

/// A viral prompt shown after completing a game, encouraging users to invite team members
struct PostGameInvitePrompt: View {
    let playerName: String
    let teamName: String
    let onInvite: () -> Void
    let onDismiss: () -> Void

    @AppStorage("postGameInviteShownCount") private var shownCount = 0
    @AppStorage("lastPostGameInviteDate") private var lastShownTimestamp: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Celebration header
            VStack(spacing: 8) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)

                Text("Great Game!")
                    .font(.title2.bold())

                Text("Share the excitement with your team")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                InviteBenefit(
                    icon: "eye.fill",
                    text: "Parents can follow along from anywhere"
                )
                InviteBenefit(
                    icon: "person.2.fill",
                    text: "Coaches can track games together"
                )
                InviteBenefit(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Everyone sees performance trends"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // CTA buttons
            VStack(spacing: 12) {
                Button {
                    trackShown()
                    onInvite()
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Invite Team Members")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    trackShown()
                    onDismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20)
        .padding(32)
    }

    private func trackShown() {
        shownCount += 1
        lastShownTimestamp = Date().timeIntervalSince1970
    }

    /// Determines if we should show this prompt
    static func shouldShow() -> Bool {
        let defaults = UserDefaults.standard
        let shownCount = defaults.integer(forKey: "postGameInviteShownCount")
        let lastShown = defaults.double(forKey: "lastPostGameInviteDate")
        let invitesSent = TeamInviteManager.shared.invitesSent

        // Don't show if user has already invited people
        if invitesSent >= 3 {
            return false
        }

        // Show first time after 2nd game
        let gamesCompleted = defaults.integer(forKey: "completedGamesCount")
        if gamesCompleted < 2 {
            return false
        }

        // Don't show too frequently (max once per week)
        let daysSinceLastShown = (Date().timeIntervalSince1970 - lastShown) / 86400
        if shownCount > 0 && daysSinceLastShown < 7 {
            return false
        }

        // Max 5 times total
        if shownCount >= 5 {
            return false
        }

        return true
    }
}

struct InviteBenefit: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Compact Invite Card (for inline placement)

struct CompactInviteCard: View {
    let onTap: () -> Void
    @State private var isVisible = true

    var body: some View {
        if isVisible {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share with your team")
                            .font(.subheadline.bold())
                        Text("Invite parents & coaches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Invite")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("Post Game Prompt") {
    ZStack {
        Color.black.opacity(0.4)
            .ignoresSafeArea()

        PostGameInvitePrompt(
            playerName: "Jack James",
            teamName: "Warriors",
            onInvite: {},
            onDismiss: {}
        )
    }
}

#Preview("Compact Card") {
    CompactInviteCard(onTap: {})
        .padding()
}
