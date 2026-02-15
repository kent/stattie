import SwiftUI

struct AchievementsView: View {
    @State private var unlockedAchievements = AchievementManager.shared.unlockedAchievements
    @State private var totalPoints = AchievementManager.shared.totalPoints

    var unlockedCount: Int {
        unlockedAchievements.count
    }

    var totalCount: Int {
        AchievementType.allCases.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with points
                VStack(spacing: 8) {
                    Text("\(totalPoints)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.accent)

                    Text("Achievement Points")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("\(unlockedCount)/\(totalCount) Unlocked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Achievement categories
                VStack(alignment: .leading, spacing: 16) {
                    AchievementSection(title: "Game Milestones", achievements: [.firstGame, .tenGames, .fiftyGames, .hundredGames], unlocked: unlockedAchievements)

                    AchievementSection(title: "Streaks", achievements: [.threeDayStreak, .sevenDayStreak, .thirtyDayStreak], unlocked: unlockedAchievements)

                    AchievementSection(title: "Performance", achievements: [.twentyPoints, .thirtyPoints, .fiftyPoints, .doubleDouble, .tripleDouble], unlocked: unlockedAchievements)

                    AchievementSection(title: "Soccer", achievements: [.hatTrick, .cleanSheet], unlocked: unlockedAchievements)

                    AchievementSection(title: "Social", achievements: [.firstShare, .sharedPlayer], unlocked: unlockedAchievements)
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementSection: View {
    let title: String
    let achievements: [AchievementType]
    let unlocked: Set<AchievementType>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(achievements, id: \.self) { achievement in
                AchievementRow(achievement: achievement, isUnlocked: unlocked.contains(achievement))
            }
        }
    }
}

struct AchievementRow: View {
    let achievement: AchievementType
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievement.color : Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? .white : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(isUnlocked ? .primary : .secondary)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                VStack(spacing: 2) {
                    Text("+\(achievement.points)")
                        .font(.caption.bold())
                        .foregroundStyle(achievement.color)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isUnlocked ? 1 : 0.7)
    }
}

// MARK: - Achievement Unlocked Toast

struct AchievementUnlockedView: View {
    let achievement: AchievementType

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.color)
                    .frame(width: 60, height: 60)

                Image(systemName: achievement.icon)
                    .font(.title)
                    .foregroundStyle(.white)
            }

            Text("Achievement Unlocked!")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(achievement.title)
                .font(.headline)

            Text("+\(achievement.points) points")
                .font(.subheadline)
                .foregroundStyle(achievement.color)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20)
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
    }
}
