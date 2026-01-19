import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var displayName = ""
    @State private var isCreating = false

    let onComplete: () -> Void

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.accent)

                    Text("Welcome to Stattie")
                        .font(.largeTitle.bold())

                    Text("Track basketball stats like a pro")
                        .font(.headline)
                        .foregroundStyle(.secondary)
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

                    Text("This is how you'll appear when tracking games")
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

        SeedDataService.shared.seedBasketballIfNeeded(context: modelContext)

        do {
            try modelContext.save()
            onComplete()
        } catch {
            print("Failed to create user: \(error)")
            isCreating = false
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: User.self, inMemory: true)
}
