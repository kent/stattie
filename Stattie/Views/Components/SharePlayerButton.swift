import SwiftUI

/// A button that initiates sharing for a player.
/// Shows different states based on whether the player is already shared.
struct SharePersonButton: View {
    let player: Person
    @Binding var isPresented: Bool

    @State private var isShared = false
    @State private var isOwner = true
    @State private var isLoading = true

    var body: some View {
        Button {
            isPresented = true
        } label: {
            if isLoading {
                Label("Share", systemImage: "square.and.arrow.up")
            } else if isShared {
                if isOwner {
                    Label("Manage Sharing", systemImage: "person.2")
                } else {
                    Label("Shared with You", systemImage: "person.2")
                }
            } else {
                Label("Share Person...", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(!isOwner && isShared)
        .task {
            await loadShareStatus()
        }
    }

    private func loadShareStatus() async {
        isShared = await player.checkIsShared()
        if isShared {
            isOwner = await player.checkIsOwner()
        }
        isLoading = false
    }
}
