import CloudKit

/// Provides the CloudKit container used by private SwiftData sync diagnostics.
final class CloudKitContainerProvider {
    static let shared = CloudKitContainerProvider()

    let cloudKitContainer: CKContainer
    let containerIdentifier = "iCloud.com.stattie.app"

    private init() {
        cloudKitContainer = CKContainer(identifier: containerIdentifier)
    }

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await cloudKitContainer.accountStatus()
    }

    func isICloudAvailable() async -> Bool {
        (try? await checkAccountStatus()) == .available
    }
}
