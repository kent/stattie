import Foundation
import CloudKit
import SwiftData
import Combine
import CoreData

@Observable
final class SyncManager {
    static let shared = SyncManager()

    private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine
    private(set) var cloudKitUserID: String?
    private(set) var isCheckingStatus = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    private(set) var isSyncInProgress = false
    private(set) var lastSyncOperation: String?
    private(set) var lastSyncErrorMessage: String?

    private var accountChangeObserver: NSObjectProtocol?
    private var cloudKitEventObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private let lastSyncDateKey = "cloudKitLastSuccessfulSyncDate"
    private let lastSyncOperationKey = "cloudKitLastSyncOperation"
    private let lastSyncErrorMessageKey = "cloudKitLastSyncErrorMessage"

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

    var syncHealthDescription: String {
        if !SharedModelContainer.isCloudKitBacked {
            return "Local only (CloudKit unavailable)"
        }

        if iCloudStatus != .available {
            return statusDescription
        }

        if isSyncInProgress {
            if let lastSyncOperation {
                return "Syncing \(lastSyncOperation.lowercased())..."
            }
            return "Syncing..."
        }

        if let lastSyncErrorMessage, !lastSyncErrorMessage.isEmpty {
            return "Sync issue"
        }

        if lastSyncDate != nil {
            return "Healthy"
        }

        return "Waiting for first sync"
    }

    private init() {
        lastSyncDate = defaults.object(forKey: lastSyncDateKey) as? Date
        lastSyncOperation = defaults.string(forKey: lastSyncOperationKey)
        lastSyncErrorMessage = defaults.string(forKey: lastSyncErrorMessageKey)

        if let lastSyncErrorMessage, !lastSyncErrorMessage.isEmpty {
            syncError = NSError(
                domain: "CloudKitSync",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: lastSyncErrorMessage]
            )
        }

        // Start observing account changes
        startObservingAccountChanges()
        startObservingCloudKitEvents()
    }

    deinit {
        stopObservingAccountChanges()
        stopObservingCloudKitEvents()
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
            }
        }
    }

    private func stopObservingAccountChanges() {
        if let observer = accountChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            accountChangeObserver = nil
        }
    }

    private func startObservingCloudKitEvents() {
        cloudKitEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
                return
            }

            Task { @MainActor in
                self.handleCloudKitEvent(event)
            }
        }
    }

    private func stopObservingCloudKitEvents() {
        if let observer = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(observer)
            cloudKitEventObserver = nil
        }
    }

    @MainActor
    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let operation = syncOperationName(for: event.type)
        lastSyncOperation = operation
        defaults.set(operation, forKey: lastSyncOperationKey)

        if event.endDate == nil {
            isSyncInProgress = true
            return
        }

        isSyncInProgress = false

        if let error = event.error {
            syncError = error
            lastSyncErrorMessage = error.localizedDescription
            defaults.set(error.localizedDescription, forKey: lastSyncErrorMessageKey)
            return
        }

        syncError = nil
        lastSyncErrorMessage = nil
        defaults.removeObject(forKey: lastSyncErrorMessageKey)

        let eventDate = event.endDate ?? Date()
        lastSyncDate = eventDate
        defaults.set(eventDate, forKey: lastSyncDateKey)

        AppState.shared.synchronizeFromCloud()
    }

    private func syncOperationName(for type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup:
            return "Setup"
        case .import:
            return "Import"
        case .export:
            return "Export"
        @unknown default:
            return "Sync"
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
        let now = Date()
        lastSyncDate = now
        defaults.set(now, forKey: lastSyncDateKey)
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
