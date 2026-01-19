import Foundation
import CloudKit
import SwiftData

@Observable
final class SyncManager {
    static let shared = SyncManager()

    private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine
    private(set) var cloudKitUserID: String?
    private(set) var isCheckingStatus = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?

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

    private init() {}

    @MainActor
    func checkiCloudStatus() async {
        isCheckingStatus = true
        defer { isCheckingStatus = false }

        do {
            let status = try await CKContainer.default().accountStatus()
            iCloudStatus = status

            if status == .available {
                await fetchCloudKitUserID()
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

    private func fetchCloudKitUserID() async {
        do {
            let recordID = try await CKContainer.default().userRecordID()
            cloudKitUserID = recordID.recordName
        } catch {
            print("Failed to fetch CloudKit user ID: \(error)")
            cloudKitUserID = nil
        }
    }

    func updateLastSyncDate() {
        lastSyncDate = Date()
    }
}
