import SwiftUI
import SwiftData
import CloudKit

@main
struct StattieApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Player.self,
            Sport.self,
            StatDefinition.self,
            Game.self,
            PlayerGameStats.self,
            Stat.self
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingShareURL(url)
                }
                .alert("Share Error", isPresented: $showShareAcceptanceError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(shareAcceptanceError ?? "Failed to accept share")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingShareURL(_ url: URL) {
        // Handle CloudKit share invitation URLs
        // Format: cloudkit-iCloud.com.stattie.app://...
        guard url.scheme == "cloudkit-iCloud.com.stattie.app" else {
            return
        }

        Task {
            do {
                try await CloudKitShareManager.shared.acceptShare(from: url)
            } catch {
                await MainActor.run {
                    shareAcceptanceError = error.localizedDescription
                    showShareAcceptanceError = true
                }
            }
        }
    }
}

// MARK: - CloudKit Share Acceptance via Scene Delegate

extension StattieApp {
    /// Handles CKShare.Metadata for share acceptance
    /// This is typically called from the SceneDelegate when opening a share URL
    @MainActor
    func acceptShare(_ metadata: CKShare.Metadata) async {
        do {
            try await CloudKitShareManager.shared.acceptShare(from: metadata)
        } catch {
            shareAcceptanceError = error.localizedDescription
            showShareAcceptanceError = true
        }
    }
}
