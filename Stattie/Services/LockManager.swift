import Foundation
import SwiftData

final class LockManager {
    static let shared = LockManager()

    private static let lockDuration: TimeInterval = 4 * 60 * 60

    private init() {}

    func acquireLock(for game: Game, userID: String, context: ModelContext) -> Bool {
        if game.isCompleted {
            return false
        }

        if let existingLock = game.lockedByUserID,
           let expiresAt = game.lockExpiresAt,
           expiresAt > Date(),
           existingLock != userID {
            return false
        }

        game.lockedByUserID = userID
        game.lockExpiresAt = Date().addingTimeInterval(Self.lockDuration)

        do {
            try context.save()
            return true
        } catch {
            print("Failed to acquire lock: \(error)")
            return false
        }
    }

    func releaseLock(for game: Game, userID: String, context: ModelContext) {
        guard game.lockedByUserID == userID else { return }

        game.lockedByUserID = nil
        game.lockExpiresAt = nil

        do {
            try context.save()
        } catch {
            print("Failed to release lock: \(error)")
        }
    }

    func refreshLock(for game: Game, userID: String, context: ModelContext) -> Bool {
        guard game.lockedByUserID == userID else { return false }

        game.lockExpiresAt = Date().addingTimeInterval(Self.lockDuration)

        do {
            try context.save()
            return true
        } catch {
            print("Failed to refresh lock: \(error)")
            return false
        }
    }

    func canEdit(game: Game, userID: String) -> Bool {
        if game.isCompleted {
            return false
        }

        if let existingLock = game.lockedByUserID,
           let expiresAt = game.lockExpiresAt,
           expiresAt > Date() {
            return existingLock == userID
        }

        return true
    }

    func isLockedByOther(game: Game, userID: String) -> Bool {
        guard let existingLock = game.lockedByUserID,
              let expiresAt = game.lockExpiresAt,
              expiresAt > Date() else {
            return false
        }
        return existingLock != userID
    }
}
