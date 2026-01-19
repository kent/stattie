import SwiftUI

/// A badge that indicates a player is shared with others.
/// Shows a person.2 icon with optional participant count.
struct SharedPlayerBadge: View {
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
struct AsyncSharedPlayerBadge: View {
    let player: Player

    @State private var isShared = false
    @State private var participantCount = 0
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                EmptyView()
            } else if isShared {
                SharedPlayerBadge(participantCount: participantCount)
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
        SharedPlayerBadge()
        SharedPlayerBadge(participantCount: 2)
        SharedPlayerBadge(participantCount: 5)
    }
    .padding()
}
