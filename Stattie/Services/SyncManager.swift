import CloudKit
import CoreData
import Foundation
import Observation

/// Observes Apple's automatic SwiftData sync. It never starts a second sync engine.
@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine
    private(set) var isCheckingStatus = false
    private(set) var activity = SyncActivity()
    private var accountError: String?
    private var observers: [NSObjectProtocol] = []

    var status: SyncStatus {
        SyncStatus.snapshot(
            isCloudKitBacked: SharedModelContainer.isCloudKitBacked,
            accountStatus: iCloudStatus,
            isCheckingStatus: isCheckingStatus,
            accountError: accountError,
            activity: activity
        )
    }

    private init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Activity from one account says nothing about another account.
                self.activity = SyncActivity()
                await self.checkiCloudStatus()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            Task { @MainActor in
                self?.activity.record(
                    id: event.identifier,
                    type: event.type,
                    endDate: event.endDate,
                    succeeded: event.succeeded,
                    errorMessage: event.error.map(CloudKitErrorFormatter.userFacingMessage)
                )
                if event.type == .import, event.endDate != nil, event.succeeded {
                    AchievementManager.shared.synchronizeFromCloud()
                }
            }
        })
    }

    func checkiCloudStatus() async {
        guard SharedModelContainer.isCloudKitBacked, !isCheckingStatus else { return }
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        do {
            iCloudStatus = try await CloudKitContainerProvider.shared.checkAccountStatus()
            accountError = nil
        } catch {
            iCloudStatus = .couldNotDetermine
            accountError = CloudKitErrorFormatter.userFacingMessage(for: error)
        }
    }
}
