import SwiftUI
import CloudKit

/// View for managing share participants for a player.
/// Shows list of participants and allows owner to stop sharing or add more people.
struct ShareManagementView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss

    @State private var participants: [CKShare.Participant] = []
    @State private var isOwner = true
    @State private var isLoading = true
    @State private var showShareSheet = false
    @State private var showStopSharingAlert = false
    @State private var showLeaveShareAlert = false
    @State private var errorMessage: String?

    private let shareManager = CloudKitShareManager.shared

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    participantsSection
                    actionsSection
                }
            }
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                SharePlayerSheet(player: player)
            }
            .alert("Stop Sharing?", isPresented: $showStopSharingAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Stop Sharing", role: .destructive) {
                    Task {
                        await stopSharing()
                    }
                }
            } message: {
                Text("Other people will no longer be able to view or track games for \(player.fullName).")
            }
            .alert("Leave Share?", isPresented: $showLeaveShareAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    Task {
                        await leaveShare()
                    }
                }
            } message: {
                Text("\(player.fullName) will be removed from your player list.")
            }
            .task {
                await loadParticipants()
            }
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        Section {
            ForEach(participants, id: \.userIdentity.userRecordID) { participant in
                ParticipantRow(participant: participant)
            }
        } header: {
            Text("People")
        } footer: {
            if isOwner {
                Text("People you share with can view all games and track new games for \(player.fullName).")
            } else {
                Text("This player was shared with you.")
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            if isOwner {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Add People", systemImage: "person.badge.plus")
                }

                Button(role: .destructive) {
                    showStopSharingAlert = true
                } label: {
                    Label("Stop Sharing", systemImage: "person.fill.xmark")
                }
            } else {
                Button(role: .destructive) {
                    showLeaveShareAlert = true
                } label: {
                    Label("Leave Share", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }

    private func loadParticipants() async {
        isLoading = true
        participants = await shareManager.getParticipants(for: player)
        isOwner = await player.checkIsOwner()
        isLoading = false
    }

    private func stopSharing() async {
        do {
            try await shareManager.stopSharing(player)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leaveShare() async {
        do {
            try await shareManager.leaveShare(player)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Row displaying a share participant
struct ParticipantRow: View {
    let participant: CKShare.Participant

    var body: some View {
        HStack {
            Circle()
                .fill(participantColor)
                .frame(width: 40, height: 40)
                .overlay {
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                HStack(spacing: 4) {
                    Text(roleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if participant.acceptanceStatus != .accepted {
                        Text("(\(statusText))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            if participant.role == .owner {
                Text("Owner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var displayName: String {
        if let nameComponents = participant.userIdentity.nameComponents {
            return PersonNameComponentsFormatter().string(from: nameComponents)
        }
        return participant.userIdentity.lookupInfo?.emailAddress ?? "Unknown"
    }

    private var initials: String {
        if let nameComponents = participant.userIdentity.nameComponents {
            let first = nameComponents.givenName?.prefix(1) ?? ""
            let last = nameComponents.familyName?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return "?"
    }

    private var participantColor: Color {
        switch participant.role {
        case .owner:
            return .blue
        case .privateUser:
            return .green
        case .publicUser:
            return .orange
        case .unknown:
            return .gray
        @unknown default:
            return .gray
        }
    }

    private var roleText: String {
        switch participant.permission {
        case .readWrite:
            return "Can edit"
        case .readOnly:
            return "View only"
        case .none, .unknown:
            return ""
        @unknown default:
            return ""
        }
    }

    private var statusText: String {
        switch participant.acceptanceStatus {
        case .pending:
            return "Invited"
        case .accepted:
            return ""
        case .removed:
            return "Removed"
        case .unknown:
            return "Unknown"
        @unknown default:
            return ""
        }
    }
}
