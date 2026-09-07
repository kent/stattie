import CloudKit
import CoreData
import Foundation

/// Observed CloudKit activity, not a queue or a measure of sync completion.
struct SyncActivity {
    private(set) var operations: [UUID: NSPersistentCloudKitContainer.EventType] = [:]
    private(set) var errors: [NSPersistentCloudKitContainer.EventType: String] = [:]
    private(set) var lastTransferDate: Date?

    mutating func record(
        id: UUID,
        type: NSPersistentCloudKitContainer.EventType,
        endDate: Date?,
        succeeded: Bool,
        errorMessage: String?
    ) {
        guard let endDate else {
            operations[id] = type
            return
        }
        operations.removeValue(forKey: id)
        guard succeeded else {
            errors[type] = errorMessage ?? "iCloud could not finish syncing."
            return
        }
        // A successful download must not hide a failed upload (or vice versa).
        errors.removeValue(forKey: type)
        if type == .import || type == .export {
            lastTransferDate = max(lastTransferDate ?? .distantPast, endDate)
        }
    }
}

struct SyncStatus: Equatable {
    let headline: String
    let detail: String
    var isActive = false
    var needsAttention = false

    static func snapshot(
        isCloudKitBacked: Bool,
        accountStatus: CKAccountStatus,
        isCheckingStatus: Bool = false,
        accountError: String? = nil,
        activity: SyncActivity = SyncActivity()
    ) -> SyncStatus {
        guard isCloudKitBacked else {
            return SyncStatus(headline: "Saved on this iPhone", detail: "iCloud sync couldn’t start. Close and reopen Stattie to try again.", needsAttention: true)
        }
        switch accountStatus {
        case .noAccount:
            return SyncStatus(headline: "Saved on this iPhone", detail: "Sign in to iCloud in iPhone Settings to sync automatically.")
        case .restricted:
            return SyncStatus(headline: "iCloud is restricted", detail: "Your data stays saved on this iPhone. Check your iCloud restrictions in iPhone Settings.", needsAttention: true)
        case .temporarilyUnavailable:
            return SyncStatus(headline: "iCloud is temporarily unavailable", detail: "Your data stays saved on this iPhone. Sync resumes automatically when iCloud is available.", needsAttention: true)
        case .couldNotDetermine:
            return SyncStatus(headline: isCheckingStatus ? "Checking iCloud" : "iCloud unavailable", detail: accountError ?? "Your data stays saved on this iPhone.", isActive: isCheckingStatus, needsAttention: !isCheckingStatus)
        case .available:
            break
        @unknown default:
            return SyncStatus(headline: "iCloud unavailable", detail: "Your data stays saved on this iPhone.", needsAttention: true)
        }
        let errors = [NSPersistentCloudKitContainer.EventType.setup, .import, .export]
            .compactMap { activity.errors[$0] }
        if !errors.isEmpty {
            return SyncStatus(headline: "iCloud needs attention", detail: errors.joined(separator: " ") + " Your data stays saved on this iPhone.", needsAttention: true)
        }
        if !activity.operations.isEmpty {
            return SyncStatus(headline: "Syncing with iCloud", detail: "Your changes sync automatically across your devices.", isActive: true)
        }
        // Account availability and past transfers cannot prove all changes synced.
        return SyncStatus(headline: "iCloud sync is on", detail: "Players, games, and achievements sync automatically across your devices.")
    }
}
