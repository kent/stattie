import SwiftUI
import SwiftData
import CloudKit

@main
struct StattieApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Person.self,
            Team.self,
            TeamMembership.self,
            Sport.self,
            StatDefinition.self,
            Game.self,
            PersonGameStats.self,
            Stat.self,
            Shift.self,
            ShiftStat.self
        ])

        // Try CloudKit first, fall back to local-only if not available
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudKitConfig])
        } catch {
            // CloudKit not available, use local storage only
            print("CloudKit not available, using local storage: \(error)")
        }

        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var shareAcceptanceError: String?
    @State private var showShareAcceptanceError = false
    @State private var showShareAcceptedSuccess = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Handle CloudKit share URLs
                .onOpenURL { url in
                    handleIncomingShareURL(url)
                }
                // Handle CloudKit share metadata from user activity (recommended approach)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    handleUserActivity(userActivity)
                }
                // Also handle CloudKit-specific activity type
                .onContinueUserActivity("com.apple.cloudkit.share") { userActivity in
                    handleUserActivity(userActivity)
                }
                .alert("Share Error", isPresented: $showShareAcceptanceError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(shareAcceptanceError ?? "Failed to accept share")
                }
                .alert("Share Accepted", isPresented: $showShareAcceptedSuccess) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("You now have access to the shared person.")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Share URL Handling

    private func handleIncomingShareURL(_ url: URL) {
        // Handle CloudKit share invitation URLs
        // Format: cloudkit-iCloud.com.stattie.app://...
        let expectedScheme = "cloudkit-\(CloudKitContainerProvider.shared.containerIdentifier)"

        guard url.scheme == expectedScheme else {
            print("Ignoring URL with unexpected scheme: \(url.scheme ?? "nil")")
            return
        }

        // For URL-based share acceptance, we need to fetch metadata first
        Task {
            do {
                // Use CKFetchShareMetadataOperation to get metadata from URL
                let metadata = try await fetchShareMetadata(from: url)
                try await CloudKitShareManager.shared.acceptShare(from: metadata)

                await MainActor.run {
                    showShareAcceptedSuccess = true
                }
            } catch {
                await MainActor.run {
                    shareAcceptanceError = error.localizedDescription
                    showShareAcceptanceError = true
                }
            }
        }
    }

    // MARK: - User Activity Handling

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        // Check if this is a CloudKit share activity
        guard let metadata = userActivity.cloudKitShareMetadata else {
            print("No CloudKit share metadata in user activity")
            return
        }

        Task {
            do {
                try await CloudKitShareManager.shared.acceptShare(from: metadata)

                await MainActor.run {
                    showShareAcceptedSuccess = true
                }
            } catch {
                await MainActor.run {
                    shareAcceptanceError = error.localizedDescription
                    showShareAcceptanceError = true
                }
            }
        }
    }

    // MARK: - Share Metadata Fetching

    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        let container = CloudKitContainerProvider.shared.cloudKitContainer

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])

            operation.perShareMetadataResultBlock = { url, result in
                switch result {
                case .success(let metadata):
                    continuation.resume(returning: metadata)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Handle completion
            operation.fetchShareMetadataResultBlock = { result in
                if case .failure(let error) = result {
                    // Only resume if not already resumed by perShareMetadataResultBlock
                    // This handles the case where there were no URLs to process
                }
            }

            container.add(operation)
        }
    }
}

// MARK: - NSUserActivity Extension

extension NSUserActivity {
    /// Extracts CloudKit share metadata from a user activity if present
    var cloudKitShareMetadata: CKShare.Metadata? {
        // The system provides share metadata in the userInfo with a specific key
        guard let userInfo = userInfo else { return nil }

        // Try the standard CloudKit key
        if let metadata = userInfo["CKShareMetadata"] as? CKShare.Metadata {
            return metadata
        }

        // Also check for the metadata in the activity's webpageURL
        // CloudKit shares come through as web activity with the share URL
        return nil
    }
}
