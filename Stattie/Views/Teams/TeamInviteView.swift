import SwiftUI
import Contacts
import ContactsUI
import UIKit

/// A viral-optimized team invitation view that makes it easy to invite
/// the whole team with one tap, with role-based messaging for coaches vs parents.
struct TeamInviteView: View {
    let team: Team?
    let players: [Person]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var inviteManager = TeamInviteManager.shared

    @State private var selectedRole: InviteRole = .parent
    @State private var customMessage = ""
    @State private var showingContactPicker = false
    @State private var selectedContacts: [InviteContact] = []
    @State private var showingSuccess = false
    @State private var inviteCount = 0

    private var teamName: String {
        team?.name ?? "My Team"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    heroSection

                    // Quick invite options
                    quickInviteSection

                    // Role selector
                    roleSelector

                    // Message preview
                    messagePreview

                    // Share button
                    shareButton

                    // Stats section
                    if inviteManager.invitesSent > 0 {
                        inviteStatsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Invite Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView(selectedContacts: $selectedContacts)
            }
            .overlay {
                if showingSuccess {
                    inviteSuccessOverlay
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Grow Your Team")
                    .font(.title2.bold())

                Text("Invite parents & coaches to track stats together")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Player count badge
            HStack {
                Image(systemName: "person.fill")
                Text("\(players.count) players on \(teamName)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
    }

    // MARK: - Quick Invite Options

    private var quickInviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK INVITE")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // Invite All Parents
            QuickInviteButton(
                title: "Invite All Parents",
                subtitle: "Send to all player families at once",
                icon: "figure.2.and.child.holdinghands",
                color: .blue
            ) {
                sendBulkInvite(role: .parent)
            }

            // Invite Coaches
            QuickInviteButton(
                title: "Invite Coaches",
                subtitle: "Let coaches track games & view stats",
                icon: "whistle.fill",
                color: .green
            ) {
                sendBulkInvite(role: .coach)
            }

            // Pick from Contacts
            QuickInviteButton(
                title: "Pick from Contacts",
                subtitle: "Choose specific people to invite",
                icon: "person.crop.circle.badge.plus",
                color: .purple
            ) {
                showingContactPicker = true
            }
        }
    }

    // MARK: - Role Selector

    private var roleSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INVITE AS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(InviteRole.allCases, id: \.self) { role in
                    RoleChip(role: role, isSelected: selectedRole == role) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedRole = role
                        }
                    }
                }
            }
        }
    }

    // MARK: - Message Preview

    private var messagePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MESSAGE PREVIEW")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Edit") {
                    // Would show custom message editor
                }
                .font(.caption)
            }

            Text(currentMessage)
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var currentMessage: String {
        switch selectedRole {
        case .parent:
            return inviteManager.teamInviteMessage(teamName: teamName, playerCount: players.count)
        case .coach:
            return inviteManager.coachInviteMessage(teamName: teamName)
        case .family:
            if let firstPlayer = players.first {
                return inviteManager.parentInviteMessage(playerName: firstPlayer.fullName, teamName: teamName)
            }
            return inviteManager.teamInviteMessage(teamName: teamName, playerCount: players.count)
        case .other:
            return inviteManager.quickTeamInvite(teamName: teamName)
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            shareInvite()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Invite")
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
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Invite Stats

    private var inviteStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR INVITES")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                InviteStatCard(
                    value: "\(inviteManager.invitesSent)",
                    label: "Sent",
                    icon: "paperplane.fill",
                    color: .blue
                )

                InviteStatCard(
                    value: "\(inviteManager.invitesAccepted)",
                    label: "Joined",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                InviteStatCard(
                    value: inviteManager.inviteConversionRate,
                    label: "Rate",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }

            // Pending invites
            if !inviteManager.pendingInvites.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Waiting to join:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(inviteManager.pendingInvites.prefix(3)) { invite in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                            Text(invite.name)
                            Spacer()
                            Text("\(invite.daysSinceSent)d ago")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }

                    if inviteManager.pendingInvites.count > 3 {
                        Text("+ \(inviteManager.pendingInvites.count - 3) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Success Overlay

    private var inviteSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Invites Sent!")
                    .font(.title2.bold())

                Text("You invited \(inviteCount) people to join \(teamName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done") {
                    withAnimation {
                        showingSuccess = false
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .padding(40)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Actions

    private func sendBulkInvite(role: InviteRole) {
        selectedRole = role
        inviteCount = players.count
        inviteManager.sendSingleInvite(
            message: currentMessage,
            contactName: "Team Parents",
            teamName: teamName
        )
    }

    private func shareInvite() {
        if selectedContacts.isEmpty {
            // Generic share
            inviteCount = 1
            inviteManager.sendSingleInvite(
                message: currentMessage,
                contactName: selectedRole.rawValue,
                teamName: teamName
            )
        } else {
            // Share to selected contacts
            inviteCount = selectedContacts.count
            inviteManager.sendBatchInvite(
                teamName: teamName,
                playerCount: players.count,
                contacts: selectedContacts
            )
        }

        // Show success after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.spring()) {
                showingSuccess = true
            }
        }
    }
}

// MARK: - Components

struct QuickInviteButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct RoleChip: View {
    let role: InviteRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: role.icon)
                    .font(.title3)
                Text(role.rawValue)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : role.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? role.color : role.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct InviteStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Contact Picker

struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var selectedContacts: [InviteContact]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView

        init(_ parent: ContactPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.selectedContacts = contacts.map { contact in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                let phone = contact.phoneNumbers.first?.value.stringValue
                let email = contact.emailAddresses.first?.value as String?
                return InviteContact(name: name, phoneOrEmail: phone ?? email)
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // User cancelled
        }
    }
}

// MARK: - Preview

#Preview {
    TeamInviteView(
        team: nil,
        players: [
            Person(firstName: "Jack", lastName: "James", jerseyNumber: 23),
            Person(firstName: "Sarah", lastName: "Smith", jerseyNumber: 11)
        ]
    )
}
