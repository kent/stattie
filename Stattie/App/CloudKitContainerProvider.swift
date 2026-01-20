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
        cloudKitContainer = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - Account Status

    /// Check if iCloud is available and user is signed in
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await cloudKitContainer.accountStatus()
    }

    /// Returns true if iCloud is available
    func isICloudAvailable() async -> Bool {
        do {
            let status = try await checkAccountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Sharing Operations

    /// Get the CKShare for a given record if it exists
    func getShare(for recordID: CKRecord.ID) async throws -> CKShare? {
        let database = cloudKitContainer.privateCloudDatabase

        do {
            let record = try await database.record(for: recordID)

            // Check if record has a share reference
            guard let shareReference = record.share else {
                return nil
            }

            // Fetch the share record using CKFetchShareMetadataOperation alternative
            // Since we have the share reference, fetch it directly
            let shareRecordID = shareReference.recordID

            // Fetch the share record directly using modern async API
            let shareRecord = try await database.record(for: shareRecordID)

            // CKShare is a subclass of CKRecord - the record should be a CKShare
            // if it was created as one. If not, we need to check the record type.
            if shareRecord.recordType == "cloudkit.share" {
                // Reconstruct as CKShare by fetching with the share-specific operation
                return try await withCheckedThrowingContinuation { continuation in
                    let operation = CKFetchRecordsOperation(recordIDs: [shareRecordID])
                    var fetchedShare: CKShare?

                    operation.perRecordResultBlock = { _, result in
                        if case .success(let record) = result, let share = record as? CKShare {
                            fetchedShare = share
                        }
                    }

                    operation.fetchRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume(returning: fetchedShare)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }

                    database.add(operation)
                }
            }

            return nil
        } catch let error as CKError {
            switch error.code {
            case .unknownItem:
                // Record doesn't exist
                return nil
            case .networkUnavailable, .networkFailure:
                throw CloudKitSharingError.networkUnavailable
            default:
                throw CloudKitSharingError.unknown(error)
            }
        } catch {
            throw CloudKitSharingError.unknown(error)
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

    /// Fetch all shares owned by the current user
    func fetchOwnedShares() async throws -> [CKShare] {
        let database = cloudKitContainer.privateCloudDatabase

        // Fetch all record zones first
        let zones = try await database.allRecordZones()
        var allShares: [CKShare] = []

        for zone in zones {
            do {
                // Use CKFetchShareParticipantsOperation to find shares
                // Or fetch records and check for share references
                let query = CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true))

                let (results, _) = try await database.records(matching: query, inZoneWith: zone.zoneID)

                for (recordID, result) in results {
                    if case .success(let record) = result {
                        // Fetch the actual share record
                        if let share = record as? CKShare {
                            allShares.append(share)
                        }
                    }
                }
            } catch let error as CKError where error.code == .unknownItem {
                // No shares in this zone, continue
                continue
            }
        }

        return allShares
    }

    /// Fetch shares that have been shared with the current user
    func fetchSharedWithMeDatabase() -> CKDatabase {
        return cloudKitContainer.sharedCloudDatabase
    }

    /// Accept an incoming share
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await cloudKitContainer.accept(metadata)
    }
}

// MARK: - Errors

enum CloudKitSharingError: LocalizedError {
    case shareCreationFailed
    case shareNotFound
    case recordNotFound
    case unauthorized
    case notSignedIn
    case networkUnavailable
    case quotaExceeded
    case zoneNotFound
    case serverError
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
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .zoneNotFound:
            return "CloudKit zone not found"
        case .serverError:
            return "iCloud server error. Please try again later."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
