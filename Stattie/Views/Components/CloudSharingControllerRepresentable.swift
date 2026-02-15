import SwiftUI
import CloudKit
import UIKit

/// SwiftUI wrapper for UICloudSharingController that presents the native iOS share sheet.
/// This provides the same sharing experience as the Notes app.
struct CloudSharingControllerRepresentable: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let player: Person
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        share[CKShare.SystemFieldKey.title] = player.fullName as CKRecordValue

        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]

        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let parent: CloudSharingControllerRepresentable

        init(_ parent: CloudSharingControllerRepresentable) {
            self.parent = parent
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error.localizedDescription)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            return parent.player.fullName
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            return parent.player.photoData
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            parent.onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            parent.onDismiss()
        }
    }
}

/// A view that prepares and presents the cloud sharing controller
struct SharePersonSheet: View {
    let player: Person
    @Environment(\.dismiss) private var dismiss

    @State private var share: CKShare?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let shareManager = CloudKitShareManager.shared
    private let container = CloudKitContainerProvider.shared.cloudKitContainer

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Preparing share...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") {
                        dismiss()
                    }
                }
                .padding()
            } else if let share {
                CloudSharingControllerRepresentable(
                    share: share,
                    container: container,
                    player: player,
                    onDismiss: { dismiss() }
                )
            }
        }
        .task {
            await prepareShare()
        }
    }

    private func prepareShare() async {
        do {
            // Check for existing share first
            if let existingShare = await shareManager.getShare(for: player) {
                share = existingShare
            } else {
                // Create new share
                share = try await shareManager.createShare(for: player)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
