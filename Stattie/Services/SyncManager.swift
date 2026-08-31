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
    private(set) var lastSyncOperation: String?
    private(set) var lastSyncErrorMessage: String?
    private(set) var inFlightPhases: Set<SyncPipelinePhase> = []
    private(set) var completedPhaseDates: [SyncPipelinePhase: Date] = [:]
    private(set) var failedPhase: SyncPipelinePhase?
    private(set) var isRetryPending = false

    private var accountChangeObserver: NSObjectProtocol?
    private var cloudKitEventObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private let lastSyncDateKey = "cloudKitLastSuccessfulSyncDate"
    private let lastSyncOperationKey = "cloudKitLastSyncOperation"
    private let lastSyncErrorMessageKey = "cloudKitLastSyncErrorMessage"
    private let failedPhaseKey = "cloudKitLastFailedPhase"

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
        progress.headline
    }

    var progress: SyncProgress {
        SyncProgress.snapshot(
            isCloudKitBacked: SharedModelContainer.isCloudKitBacked,
            accountStatus: iCloudStatus,
            isCheckingStatus: isCheckingStatus,
            isRetryPending: isRetryPending,
            inFlightPhases: inFlightPhases,
            completedDates: completedPhaseDates,
            failedPhase: failedPhase,
            errorMessage: lastSyncErrorMessage,
            lastSyncDate: lastSyncDate
        )
    }

    var isSyncInProgress: Bool {
        isRetryPending || !inFlightPhases.isEmpty
    }

    private init() {
        lastSyncDate = defaults.object(forKey: lastSyncDateKey) as? Date
        lastSyncOperation = defaults.string(forKey: lastSyncOperationKey)
        if lastSyncOperation == "Retry" {
            lastSyncOperation = nil
            defaults.removeObject(forKey: lastSyncOperationKey)
        }
        lastSyncErrorMessage = defaults.string(forKey: lastSyncErrorMessageKey)
        completedPhaseDates = loadCompletedPhaseDates()
        if let rawFailedPhase = defaults.string(forKey: failedPhaseKey) {
            failedPhase = SyncPipelinePhase(rawValue: rawFailedPhase)
        }

        if let lastSyncErrorMessage, !lastSyncErrorMessage.isEmpty {
            syncError = NSError(
                domain: "CloudKitSync",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: lastSyncErrorMessage]
            )
        }

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
        let phase = SyncPipelinePhase(eventType: event.type)
        if let phase {
            lastSyncOperation = phase.title
            defaults.set(phase.title, forKey: lastSyncOperationKey)
        }
        isRetryPending = false

        if event.endDate == nil {
            if let phase {
                inFlightPhases.insert(phase)
                if failedPhase == phase {
                    failedPhase = nil
                    defaults.removeObject(forKey: failedPhaseKey)
                }
            }
            return
        }

        if let phase {
            inFlightPhases.remove(phase)
        }

        if let error = event.error {
            syncError = error
            let message = CloudKitErrorFormatter.userFacingMessage(for: error)
            lastSyncErrorMessage = message
            defaults.set(message, forKey: lastSyncErrorMessageKey)
            if let phase {
                failedPhase = phase
                defaults.set(phase.rawValue, forKey: failedPhaseKey)
            }
            return
        }

        syncError = nil
        lastSyncErrorMessage = nil
        failedPhase = nil
        defaults.removeObject(forKey: lastSyncErrorMessageKey)
        defaults.removeObject(forKey: failedPhaseKey)

        let eventDate = event.endDate ?? Date()
        lastSyncDate = eventDate
        defaults.set(eventDate, forKey: lastSyncDateKey)
        if let phase {
            completedPhaseDates[phase] = eventDate
            defaults.set(eventDate, forKey: completedDateKey(for: phase))
        }

        // Import is the only event that can bring new SwiftData rows. Export and
        // setup must not rewrite preference records or they dirty CloudKit again.
        if event.type == .import {
            AppState.shared.synchronizeFromCloud()
        }
    }

    @MainActor
    func retrySync() async {
        lastSyncErrorMessage = nil
        syncError = nil
        failedPhase = nil
        defaults.removeObject(forKey: lastSyncErrorMessageKey)
        defaults.removeObject(forKey: failedPhaseKey)
        isRetryPending = true

        if let context = SharedModelContainer.container?.mainContext {
            do {
                _ = try PlayerPhotoStore.migrateOversizedPhotos(in: context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                lastSyncErrorMessage = error.localizedDescription
                defaults.set(error.localizedDescription, forKey: lastSyncErrorMessageKey)
                isRetryPending = false
                return
            }
        }

        await checkiCloudStatus()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            if inFlightPhases.isEmpty {
                isRetryPending = false
            }
        }
    }

    private func completedDateKey(for phase: SyncPipelinePhase) -> String {
        "cloudKitPhaseCompletedDate.\(phase.rawValue)"
    }

    private func loadCompletedPhaseDates() -> [SyncPipelinePhase: Date] {
        var dates: [SyncPipelinePhase: Date] = [:]
        for phase in SyncPipelinePhase.allCases {
            if let date = defaults.object(forKey: completedDateKey(for: phase)) as? Date {
                dates[phase] = date
            }
        }
        return dates
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
