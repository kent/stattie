import Foundation
import SwiftData
import CloudKit

/// Manages CloudKit sharing for Person records.
/// Creates shareable CloudKit records linked to SwiftData Person entities.
///
/// Architecture:
/// - SwiftData manages the primary Person data with automatic CloudKit sync
/// - For sharing, we create separate CKRecords in a dedicated sharing zone
/// - These share records are linked to People via the Person's UUID
/// - Recipients see a read-only snapshot that can be refreshed
@MainActor
@Observable
final class CloudKitShareManager {
    static let shared = CloudKitShareManager()

    private let provider = CloudKitContainerProvider.shared

    // Use a dedicated zone for sharing to avoid conflicts with SwiftData's zone
    private let sharingZoneName = "PersonSharingZone"
    private var sharingZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: sharingZoneName, ownerName: CKCurrentUserDefaultName)
    }

    // Cache of shares by person ID
    private var shareCache: [UUID: CKShare] = [:]

    // Track zone creation
    private var zoneCreated = false

    // Currently active share for presentation
    private(set) var activeShare: CKShare?
    private(set) var activePersonID: UUID?

    var isLoading = false
    var errorMessage: String?

    private init() {}

    // MARK: - Zone Management

    /// Ensures the sharing zone exists
    private func ensureSharingZoneExists() async throws {
        guard !zoneCreated else { return }

        let zone = CKRecordZone(zoneID: sharingZoneID)
        do {
            _ = try await provider.cloudKitContainer.privateCloudDatabase.save(zone)
            zoneCreated = true
        } catch let error as CKError {
            // Zone already exists is fine
            if error.code == .serverRecordChanged || error.code == .zoneNotFound {
                zoneCreated = true
            } else {
                throw error
            }
        }
    }

    // MARK: - Share Creation

    /// Creates a CKShare for a person and returns it for presentation
    func createShare(for person: Person) async throws -> CKShare {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Check iCloud status first
        let status = try await provider.cloudKitContainer.accountStatus()
        guard status == .available else {
            errorMessage = "Please sign in to iCloud"
            throw CloudKitSharingError.notSignedIn
        }

        // Ensure zone exists
        try await ensureSharingZoneExists()

        // Check if share already exists
        if let existingShare = await getShare(for: person) {
            activeShare = existingShare
            activePersonID = person.id
            return existingShare
        }

        // Create a CKRecord for the person in our sharing zone
        let recordID = CKRecord.ID(recordName: "Person_\(person.id.uuidString)", zoneID: sharingZoneID)
        let personRecord = CKRecord(recordType: "SharedPerson", recordID: recordID)

        // Set person data
        personRecord["firstName"] = person.firstName as CKRecordValue
        personRecord["lastName"] = person.lastName as CKRecordValue
        personRecord["jerseyNumber"] = person.jerseyNumber as CKRecordValue
        personRecord["position"] = person.position as CKRecordValue
        personRecord["personID"] = person.id.uuidString as CKRecordValue

        // Create the share
        let share = CKShare(rootRecord: personRecord)
        share[CKShare.SystemFieldKey.title] = person.fullName as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.stattie.person" as CKRecordValue
        share.publicPermission = .none // Only invited participants

        // Save both records using modern async API with retry logic
        let database = provider.cloudKitContainer.privateCloudDatabase

        do {
            // Use modifyRecords for atomic save of record + share
            let (savedResults, _) = try await database.modifyRecords(
                saving: [personRecord, share],
                deleting: [],
                savePolicy: .changedKeys
            )

            // Find the saved share in results
            var savedShare: CKShare?
            for (_, result) in savedResults {
                if case .success(let record) = result, let s = record as? CKShare {
                    savedShare = s
                    break
                }
            }

            guard let finalShare = savedShare else {
                throw CloudKitSharingError.shareCreationFailed
            }

            // Cache and set active
            shareCache[person.id] = finalShare
            activeShare = finalShare
            activePersonID = person.id

            return finalShare

        } catch let error as CKError {
            errorMessage = mapCKError(error)
            throw CloudKitSharingError.unknown(error)
        } catch {
            errorMessage = error.localizedDescription
            throw CloudKitSharingError.unknown(error)
        }
    }

    // MARK: - Share Retrieval

    /// Gets existing share for a person if one exists
    func getShare(for person: Person) async -> CKShare? {
        // Check cache first
        if let cached = shareCache[person.id] {
            return cached
        }

        let recordID = CKRecord.ID(recordName: "Person_\(person.id.uuidString)", zoneID: sharingZoneID)

        do {
            let share = try await provider.getShare(for: recordID)
            if let share = share {
                shareCache[person.id] = share
            }
            return share
        } catch {
            // Record doesn't exist or other error
            return nil
        }
    }

    /// Checks if a person is currently shared
    func isPersonShared(_ person: Person) async -> Bool {
        return await getShare(for: person) != nil
    }

    // MARK: - Share Management

    /// Stops sharing a person (removes the share)
    func stopSharing(_ person: Person) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let share = await getShare(for: person) else {
            throw CloudKitSharingError.shareNotFound
        }

        let database = provider.cloudKitContainer.privateCloudDatabase

        // Delete the share record (this removes all participants)
        do {
            try await database.deleteRecord(withID: share.recordID)
        } catch let error as CKError {
            errorMessage = mapCKError(error)
            throw CloudKitSharingError.unknown(error)
        }

        // Clear from cache
        shareCache.removeValue(forKey: person.id)
        if activePersonID == person.id {
            activeShare = nil
            activePersonID = nil
        }
    }

    /// Gets participants for a shared person
    func getParticipants(for person: Person) async -> [CKShare.Participant] {
        guard let share = await getShare(for: person) else {
            return []
        }
        // Filter to return only non-owner participants
        return share.participants.filter { $0.role != .owner }
    }

    // MARK: - Share Acceptance

    /// Accepts an incoming share invitation from metadata
    func acceptShare(from metadata: CKShare.Metadata) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await provider.acceptShare(metadata)
        } catch let error as CKError {
            errorMessage = mapCKError(error)
            throw CloudKitSharingError.unknown(error)
        }
    }

    // MARK: - Leave Share

    /// Leave a share that was shared with the current user
    func leaveShare(_ person: Person) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let share = await getShare(for: person) else {
            throw CloudKitSharingError.shareNotFound
        }

        guard let currentUserParticipant = share.currentUserParticipant else {
            throw CloudKitSharingError.unauthorized
        }

        // Can't leave if you're the owner
        if currentUserParticipant.role == .owner {
            throw CloudKitSharingError.unauthorized
        }

        // Remove self from share
        share.removeParticipant(currentUserParticipant)

        // Save changes with retry logic
        let database = provider.cloudKitContainer.privateCloudDatabase

        do {
            _ = try await database.save(share)
        } catch let error as CKError {
            if error.code == .serverRecordChanged {
                // Fetch latest and retry once
                if let latestShare = try? await provider.getShare(
                    for: CKRecord.ID(recordName: "Person_\(person.id.uuidString)", zoneID: sharingZoneID)
                ), let participant = latestShare.currentUserParticipant {
                    latestShare.removeParticipant(participant)
                    _ = try await database.save(latestShare)
                }
            } else {
                errorMessage = mapCKError(error)
                throw CloudKitSharingError.unknown(error)
            }
        }

        // Clear cache
        shareCache.removeValue(forKey: person.id)
    }

    // MARK: - Utilities

    /// Clears the share cache
    func clearCache() {
        shareCache.removeAll()
        activeShare = nil
        activePersonID = nil
    }

    /// Check if current user is the owner of a share
    func isOwner(of person: Person) async -> Bool {
        guard let share = await getShare(for: person) else {
            return true // If not shared, current user owns it
        }

        guard let currentUser = share.currentUserParticipant else {
            return false
        }

        return currentUser.role == .owner
    }

    /// Gets the number of participants for a shared person (excluding owner)
    func getParticipantCount(for person: Person) async -> Int {
        guard let share = await getShare(for: person) else {
            return 0
        }
        // Subtract 1 to exclude owner
        return max(0, share.participants.count - 1)
    }

    // MARK: - Error Mapping

    private func mapCKError(_ error: CKError) -> String {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return "Network unavailable. Please check your connection."
        case .notAuthenticated:
            return "Please sign in to iCloud."
        case .quotaExceeded:
            return "iCloud storage quota exceeded."
        case .serverRejectedRequest:
            return "Request rejected by iCloud. Please try again."
        case .zoneBusy:
            return "iCloud is busy. Please try again in a moment."
        case .limitExceeded:
            return "Too many operations. Please try again later."
        case .permissionFailure:
            return "Permission denied. Check your iCloud settings."
        default:
            return error.localizedDescription
        }
    }
}
