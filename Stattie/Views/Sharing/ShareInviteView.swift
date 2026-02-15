import SwiftUI
import CloudKit
import UIKit

/// A beautiful, Apple HIG-compliant share invitation view.
/// Provides context about what sharing means and offers multiple sharing options.
struct ShareInviteView: View {
    let player: Person
    @Environment(\.dismiss) private var dismiss

    @State private var showingCloudShare = false
    @State private var showingShareLink = false
    @State private var isPreparingShare = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    private let shareManager = CloudKitShareManager.shared

    // App Store URL - update with actual App Store ID when published
    private static let appStoreURL = URL(string: "https://apps.apple.com/app/stattie/id6738968579")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with player info
                    playerHeader

                    // What sharing does
                    sharingExplanation

                    // Share options
                    shareOptions

                    // Footer note
                    footerNote
                }
                .padding()
            }
            .navigationTitle("Share \(player.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCloudShare) {
                SharePersonSheet(player: player)
            }
            .sheet(isPresented: $showingShareLink) {
                if let url = shareURL {
                    ShareLinkSheet(url: url, player: player)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Player Header

    private var playerHeader: some View {
        VStack(spacing: 12) {
            if let photoData = player.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Text("#\(player.jerseyNumber)")
                        .font(.title.bold())
                        .foregroundStyle(.accent)
                }
            }

            Text(player.fullName)
                .font(.title2.bold())

            if !player.position.isEmpty {
                Text(player.position)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Sharing Explanation

    private var sharingExplanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share with Family & Coaches")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ShareFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    title: "View all games & stats",
                    description: "Everyone can see game history and performance trends"
                )

                ShareFeatureRow(
                    icon: "plus.circle",
                    color: .green,
                    title: "Record games together",
                    description: "Anyone can track new games when you're not available"
                )

                ShareFeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange,
                    title: "Always in sync",
                    description: "Changes sync automatically to everyone's devices"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Share Options

    private var shareOptions: some View {
        VStack(spacing: 12) {
            // Primary: iCloud Share
            Button {
                showingCloudShare = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite via iCloud")
                            .font(.headline)
                        Text("They'll need the Stattie app")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding()
                .foregroundStyle(.white)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Secondary: Share app link
            Button {
                shareAppDownloadLink()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.app")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share App Download Link")
                            .font(.headline)
                        Text("Send them a link to get Stattie first")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .foregroundStyle(.primary)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Footer Note

    private var footerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.secondary)

            Text("Only people you invite can see this player's information")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func shareAppDownloadLink() {
        shareURL = Self.appStoreURL
        showingShareLink = true
    }
}

// MARK: - Share Feature Row

private struct ShareFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Share Link Sheet

private struct ShareLinkSheet: UIViewControllerRepresentable {
    let url: URL
    let player: Person

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let message = """
        Track \(player.fullName)'s game stats with Stattie!

        Download the app to view games and record stats together.
        """

        let items: [Any] = [message, url]
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ShareInviteView(player: Person(firstName: "John", lastName: "Smith", jerseyNumber: 23, position: "Guard"))
}
