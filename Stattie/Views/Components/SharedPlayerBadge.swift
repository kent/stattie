import SwiftUI

/// A badge that indicates a player is shared with others.
/// Shows a person.2 icon with optional participant count.
struct SharedPersonBadge: View {
    let participantCount: Int

    init(participantCount: Int = 0) {
        self.participantCount = participantCount
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            if participantCount > 0 {
                Text("\(participantCount)")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.blue.opacity(0.15))
        .clipShape(Capsule())
    }
}

/// An async badge that loads sharing status for a player
struct AsyncSharedPersonBadge: View {
    let player: Person

    @State private var isShared = false
    @State private var participantCount = 0
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                EmptyView()
            } else if isShared {
                SharedPersonBadge(participantCount: participantCount)
            }
        }
        .task {
            await loadShareStatus()
        }
    }

    private func loadShareStatus() async {
        isShared = await player.checkIsShared()
        if isShared {
            participantCount = await player.getShareParticipantCount()
        }
        isLoading = false
    }
}

#Preview {
    VStack(spacing: 20) {
        SharedPersonBadge()
        SharedPersonBadge(participantCount: 2)
        SharedPersonBadge(participantCount: 5)
    }
    .padding()
}
