import Foundation
import CloudKit
import SwiftData
import Combine

@Observable
final class SyncManager {
    static let shared = SyncManager()

    private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine
    private(set) var cloudKitUserID: String?
    private(set) var isCheckingStatus = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

    private var accountChangeObserver: NSObjectProtocol?

    var isSignedIntoiCloud: Bool {
        iCloudStatus == .available
    }

    var statusDescription: String {
        switch iCloudStatus {
        case .available:
            return "Signed in"
        case .noAccount:
            return "Not signed in"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    private init() {
        // Start observing account changes
        startObservingAccountChanges()
    }

    deinit {
        stopObservingAccountChanges()
    }

    // MARK: - Account Change Monitoring

    private func startObservingAccountChanges() {
        // Observe CKAccountChanged notification
        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkiCloudStatus()

                // Clear share cache when account changes
                await CloudKitShareManager.shared.clearCache()
            }
        }
    }

    private func stopObservingAccountChanges() {
        if let observer = accountChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            accountChangeObserver = nil
        }
    }

    // MARK: - Status Checking

    @MainActor
    func checkiCloudStatus() async {
        isCheckingStatus = true
        defer { isCheckingStatus = false }

        // Use the same container as CloudKitContainerProvider
        let container = CloudKitContainerProvider.shared.cloudKitContainer

        do {
            let status = try await container.accountStatus()
            iCloudStatus = status

            if status == .available {
                await fetchCloudKitUserID(from: container)
            } else {
                cloudKitUserID = nil
            }
            syncError = nil
        } catch {
            syncError = error
            iCloudStatus = .couldNotDetermine
            cloudKitUserID = nil
        }
    }

    private func fetchCloudKitUserID(from container: CKContainer) async {
        do {
            let recordID = try await container.userRecordID()
            await MainActor.run {
                cloudKitUserID = recordID.recordName
            }
        } catch {
            print("Failed to fetch CloudKit user ID: \(error)")
            await MainActor.run {
                cloudKitUserID = nil
            }
        }
    }

    // MARK: - Sync Status

    func updateLastSyncDate() {
        lastSyncDate = Date()
    }

    /// Formatted description of the last sync
    var lastSyncDescription: String {
        guard let date = lastSyncDate else {
            return "Never synced"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
