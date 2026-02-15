import SwiftUI
import SwiftData

enum SportSelection: String, CaseIterable, Identifiable {
    case basketball = "Basketball"
    case soccer = "Soccer"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .soccer: return "soccerball"
        }
    }

    var description: String {
        switch self {
        case .basketball: return "Track shots, rebounds, assists & more"
        case .soccer: return "Track goals, saves, passes & more"
        }
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var displayName = ""
    @State private var selectedSports: Set<SportSelection> = [.basketball]
    @State private var isCreating = false
    @State private var currentPage = 0

    let onComplete: () -> Void

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedSports.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "basketball.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Image(systemName: "soccerball")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                    }

                    Text("Welcome to Stattie")
                        .font(.largeTitle.bold())

                    Text("The easiest way to track game stats")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Value props
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "hand.tap.fill", text: "One-tap stat tracking", color: .blue)
                        FeatureRow(icon: "person.2.fill", text: "Share with family & coaches", color: .green)
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "See performance trends", color: .purple)
                    }
                    .padding(.top, 8)
                }

                Spacer()

                VStack(spacing: 16) {
                    Text("What should we call you?")
                        .font(.headline)

                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 16) {
                    Text("Which sports do you track?")
                        .font(.headline)

                    HStack(spacing: 16) {
                        ForEach(SportSelection.allCases) { sport in
                            SportSelectionCard(
                                sport: sport,
                                isSelected: selectedSports.contains(sport)
                            ) {
                                if selectedSports.contains(sport) {
                                    selectedSports.remove(sport)
                                } else {
                                    selectedSports.insert(sport)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Text("You can add more sports later")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    createUser()
                } label: {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Get Started")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 32)
                .disabled(!isValid || isCreating)

                Spacer()
                    .frame(height: 32)
            }
        }
    }

    private func createUser() {
        isCreating = true

        let user = User(displayName: displayName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(user)

        // Seed all selected sports
        if selectedSports.contains(.basketball) {
            SeedDataService.shared.seedBasketballIfNeeded(context: modelContext)
        }
        if selectedSports.contains(.soccer) {
            SeedDataService.shared.seedSoccerIfNeeded(context: modelContext)
        }

        // Request notification permission
        Task {
            await NotificationManager.shared.requestPermission()
        }

        do {
            try modelContext.save()
            onComplete()
        } catch {
            print("Failed to create user: \(error)")
            isCreating = false
        }
    }
}

// MARK: - First Player Prompt

struct FirstPlayerPromptView: View {
    @Binding var isPresented: Bool
    let onAddPlayer: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("Ready to track your first game?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Add a player to get started. You can add their name, jersey number, and position.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    onAddPlayer()
                    isPresented = false
                } label: {
                    Text("Add Your First Player")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    isPresented = false
                } label: {
                    Text("I'll do this later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

struct SportSelectionCard: View {
    let sport: SportSelection
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: sport.iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(isSelected ? .white : .accent)

                Text(sport.rawValue)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(sport.description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: User.self, inMemory: true)
}
