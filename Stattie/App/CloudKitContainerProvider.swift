import Foundation
import SwiftData
import CloudKit

/// Provides CloudKit container access for sharing features.
/// Works alongside SwiftData's automatic CloudKit sync.
final class CloudKitContainerProvider {
    static let shared = CloudKitContainerProvider()

    let cloudKitContainer: CKContainer
    let containerIdentifier = "iCloud.com.stattie.app"

    private init() {
        cloudKitContainer = CKContainer(identifier: "iCloud.com.stattie.app")
    }

    // MARK: - Sharing Operations

    /// Get the CKShare for a given record if it exists
    func getShare(for recordID: CKRecord.ID) async throws -> CKShare? {
        let database = cloudKitContainer.privateCloudDatabase

        do {
            let record = try await database.record(for: recordID)
            if let shareReference = record.share {
                return try await database.record(for: shareReference.recordID) as? CKShare
            }
            return nil
        } catch {
            // Record not found or no share
            return nil
        }
    }

    /// Check if a record is shared
    func isRecordShared(_ recordID: CKRecord.ID) async -> Bool {
        do {
            let share = try await getShare(for: recordID)
            return share != nil
        } catch {
            return false
        }
    }

    /// Fetch shares for the current user
    func fetchAllShares() async throws -> [CKShare] {
        let zones = try await cloudKitContainer.privateCloudDatabase.allRecordZones()
        var allShares: [CKShare] = []

        for zone in zones {
            let query = CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true))
            let (results, _) = try await cloudKitContainer.privateCloudDatabase.records(matching: query, inZoneWith: zone.zoneID)

            for (_, result) in results {
                if case .success(let record) = result, let share = record as? CKShare {
                    allShares.append(share)
                }
            }
        }

        return allShares
    }
}

// MARK: - Errors

enum CloudKitSharingError: LocalizedError {
    case shareCreationFailed
    case shareNotFound
    case recordNotFound
    case unauthorized
    case notSignedIn
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .shareCreationFailed:
            return "Failed to create share"
        case .shareNotFound:
            return "Share not found"
        case .recordNotFound:
            return "Record not found"
        case .unauthorized:
            return "Not authorized to perform this action"
        case .notSignedIn:
            return "Please sign in to iCloud to share players"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
