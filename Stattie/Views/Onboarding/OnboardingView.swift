import SwiftUI
import SwiftData

struct SportSelection: Identifiable, Hashable {
    let name: String
    let iconName: String
    let description: String

    var id: String { name }

    static var allCases: [SportSelection] {
        SportCatalog.all.map {
            SportSelection(name: $0.name, iconName: $0.iconName, description: $0.summary)
        }
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var displayName = ""
    @State private var selectedSports: Set<String> = ["Basketball"]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isCreating = false
    @State private var currentPage = 0

    let onComplete: () -> Void

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedSports.isEmpty
    }

    @ViewBuilder
    private var sportCards: some View {
        ForEach(SportSelection.allCases) { sport in
            SportSelectionCard(
                sport: sport,
                isSelected: selectedSports.contains(sport.name)
            ) {
                if selectedSports.contains(sport.name) {
                    selectedSports.remove(sport.name)
                } else {
                    selectedSports.insert(sport.name)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "basketball.fill")
                            .scaledFont(size: 28, relativeTo: .largeTitle)
                            .foregroundStyle(.orange)
                        Image(systemName: "soccerball")
                            .scaledFont(size: 28, relativeTo: .largeTitle)
                            .foregroundStyle(.green)
                        Image(systemName: "figure.hockey")
                            .scaledFont(size: 28, relativeTo: .largeTitle)
                            .foregroundStyle(.blue)
                        Image(systemName: "figure.baseball")
                            .scaledFont(size: 28, relativeTo: .largeTitle)
                            .foregroundStyle(.red)
                    }

                    Text("Welcome to Stattie")
                        .font(.largeTitle.bold())

                    Text("Track one player’s game, one tap at a time")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Value props
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "hand.tap.fill", text: "Track one player per game", color: .blue)
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Review your player’s progress", color: .green)
                        FeatureRow(icon: "heart.fill", text: "Built for parents in the stands", color: .purple)
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

                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 16) {
                                sportCards
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                sportCards
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
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
    }

    private func createUser() {
        isCreating = true

        let user = User(displayName: displayName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(user)

        SeedDataService.shared.seedSelectedSports(selectedSports, context: modelContext)
        SeedDataService.shared.seedAllSportsIfNeeded(context: modelContext)

        // Request notification permission
        Task {
            await NotificationManager.shared.requestPermission()
        }

        do {
            try modelContext.save()
            AppState.shared.completeOnboarding(userID: user.id)
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
                .scaledFont(size: 60, relativeTo: .largeTitle)
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
                    .scaledFont(size: 36, relativeTo: .title1)
                    .foregroundStyle(isSelected ? .white : .accent)

                Text(sport.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(sport.description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sport.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to toggle this sport")
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
