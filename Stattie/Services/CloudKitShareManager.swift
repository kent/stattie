import Foundation
import SwiftData
import CloudKit

/// Manages CloudKit sharing for Player records.
/// Enables Notes-like collaborative sharing where owners can share players with family members.
@MainActor
@Observable
final class CloudKitShareManager {
    static let shared = CloudKitShareManager()

    private let provider = CloudKitContainerProvider.shared
    private let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserRecordName)

    // Cache of shares by player ID
    private var shareCache: [UUID: CKShare] = [:]

    // Currently active share for presentation
    private(set) var activeShare: CKShare?
    private(set) var activePlayerID: UUID?

    var isLoading = false
    var errorMessage: String?

    private init() {}

    // MARK: - Share Creation

    /// Creates a CKShare for a player and returns it for presentation
    func createShare(for player: Player) async throws -> CKShare {
        isLoading = true
        defer { isLoading = false }

        // Check iCloud status first
        let status = try await provider.cloudKitContainer.accountStatus()
        guard status == .available else {
            throw CloudKitSharingError.notSignedIn
        }

        // Create a record zone if needed
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await provider.cloudKitContainer.privateCloudDatabase.save(zone)
        } catch {
            // Zone may already exist, which is fine
        }

        // Create a CKRecord for the player
        let recordID = CKRecord.ID(recordName: player.id.uuidString, zoneID: zoneID)
        let playerRecord = CKRecord(recordType: "CD_Player", recordID: recordID)

        // Set basic metadata that CloudKit needs
        playerRecord["CD_firstName"] = player.firstName as CKRecordValue
        playerRecord["CD_lastName"] = player.lastName as CKRecordValue
        playerRecord["CD_jerseyNumber"] = player.jerseyNumber as CKRecordValue
        playerRecord["CD_position"] = player.position as CKRecordValue
        playerRecord["CD_id"] = player.id.uuidString as CKRecordValue

        // Save the record first
        do {
            _ = try await provider.cloudKitContainer.privateCloudDatabase.save(playerRecord)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Record already exists, fetch it instead
        } catch {
            throw CloudKitSharingError.unknown(error)
        }

        // Create the share
        let share = CKShare(rootRecord: playerRecord)
        share[CKShare.SystemFieldKey.title] = player.fullName as CKRecordValue
        share.publicPermission = .none // Only invited participants can access

        // Save the share
        let operation = CKModifyRecordsOperation(recordsToSave: [playerRecord, share], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    self.shareCache[player.id] = share
                    self.activeShare = share
                    self.activePlayerID = player.id
                    continuation.resume(returning: share)
                case .failure(let error):
                    continuation.resume(throwing: CloudKitSharingError.unknown(error))
                }
            }
            provider.cloudKitContainer.privateCloudDatabase.add(operation)
        }
    }

    /// Gets existing share for a player if one exists
    func getShare(for player: Player) async -> CKShare? {
        // Check cache first
        if let cached = shareCache[player.id] {
            return cached
        }

        let recordID = CKRecord.ID(recordName: player.id.uuidString, zoneID: zoneID)
        do {
            let share = try await provider.getShare(for: recordID)
            if let share = share {
                shareCache[player.id] = share
            }
            return share
        } catch {
            return nil
        }
    }

    /// Checks if a player is currently shared
    func isPlayerShared(_ player: Player) async -> Bool {
        return await getShare(for: player) != nil
    }

    // MARK: - Share Management

    /// Stops sharing a player (removes all participants)
    func stopSharing(_ player: Player) async throws {
        isLoading = true
        defer { isLoading = false }

        guard let share = await getShare(for: player) else {
            throw CloudKitSharingError.shareNotFound
        }

        let recordID = CKRecord.ID(recordName: player.id.uuidString, zoneID: zoneID)

        // Delete the share record
        try await provider.cloudKitContainer.privateCloudDatabase.deleteRecord(withID: share.recordID)

        // Clear from cache
        shareCache.removeValue(forKey: player.id)
        if activePlayerID == player.id {
            activeShare = nil
            activePlayerID = nil
        }
    }

    /// Gets participants for a shared player
    func getParticipants(for player: Player) async -> [CKShare.Participant] {
        guard let share = await getShare(for: player) else {
            return []
        }
        return share.participants
    }

    // MARK: - Share Acceptance

    /// Accepts an incoming share invitation
    func acceptShare(from metadata: CKShare.Metadata) async throws {
        isLoading = true
        defer { isLoading = false }

        try await provider.cloudKitContainer.accept(metadata)
    }

    /// Accepts share from a URL (called from onOpenURL)
    func acceptShare(from url: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        // Parse the CloudKit share URL
        // Format: cloudkit-iCloud.com.stattie.app://...
        guard url.scheme == "cloudkit-iCloud.com.stattie.app" else {
            throw CloudKitSharingError.unknown(NSError(domain: "InvalidURL", code: -1))
        }

        // Fetch the share metadata from the URL
        // This is handled by the system when the app opens via the URL
    }

    // MARK: - Leave Share

    /// Leave a share that was shared with the current user
    func leaveShare(_ player: Player) async throws {
        isLoading = true
        defer { isLoading = false }

        guard let share = await getShare(for: player) else {
            throw CloudKitSharingError.shareNotFound
        }

        // Find current user participant
        guard let currentUserParticipant = share.currentUserParticipant else {
            throw CloudKitSharingError.unauthorized
        }

        // Remove self from share
        share.removeParticipant(currentUserParticipant)

        // Save changes
        try await provider.cloudKitContainer.privateCloudDatabase.save(share)

        // Clear cache
        shareCache.removeValue(forKey: player.id)
    }

    // MARK: - Utilities

    /// Clears the share cache
    func clearCache() {
        shareCache.removeAll()
        activeShare = nil
        activePlayerID = nil
    }

    /// Check if current user is the owner of a share
    func isOwner(of player: Player) async -> Bool {
        guard let share = await getShare(for: player) else {
            return true // If not shared, current user owns it
        }

        guard let currentUser = share.currentUserParticipant else {
            return false
        }

        return currentUser.role == .owner
    }

    /// Gets the number of participants for a shared player (excluding owner)
    func getParticipantCount(for player: Player) async -> Int {
        guard let share = await getShare(for: player) else {
            return 0
        }
        // Subtract 1 to exclude owner
        return max(0, share.participants.count - 1)
    }
}
