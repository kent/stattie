import Foundation
import SwiftData

enum CloudSyncedPreferences {
    private static let defaults = UserDefaults.standard
    private static let localUpdatedAtKey = "cloudSyncedPreferencesLocalUpdatedAt"
    private static let stateFetchLimit = 1

    private static var hasBootstrapped = false

    static func bootstrapIfNeeded(force: Bool = false) {
        if hasBootstrapped && !force { return }
        hasBootstrapped = true
        synchronizeFromCloudIfAvailable()
    }

    static func notifyLocalMutation() {
        defaults.set(Date().timeIntervalSince1970, forKey: localUpdatedAtKey)
        pushLocalStateToCloudIfAvailable()
    }

    static func synchronizeFromCloudIfAvailable() {
        guard let context = SharedModelContainer.makeContext() else { return }
        let state = fetchOrCreateState(in: context)

        let remoteUpdatedAt = state.updatedAt.timeIntervalSince1970
        let localUpdatedAt = defaults.double(forKey: localUpdatedAtKey)

        if remoteUpdatedAt > localUpdatedAt {
            apply(state: state)
            defaults.set(remoteUpdatedAt, forKey: localUpdatedAtKey)
            return
        }

        if localUpdatedAt == 0 {
            // First run on this device: persist local defaults and mark timestamp.
            defaults.set(Date().timeIntervalSince1970, forKey: localUpdatedAtKey)
        }

        pushLocalStateToCloudIfAvailable()
    }

    static func pushLocalStateToCloudIfAvailable() {
        guard let context = SharedModelContainer.makeContext() else { return }
        let state = fetchOrCreateState(in: context)
        guard applyLocalDefaultsIfNeeded(to: state) else { return }
        save(context: context)
    }

    private static func fetchOrCreateState(in context: ModelContext) -> SyncedAppSettings {
        var descriptor = FetchDescriptor<SyncedAppSettings>()
        descriptor.fetchLimit = stateFetchLimit

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let created = SyncedAppSettings()
        context.insert(created)
        _ = applyLocalDefaultsIfNeeded(to: created)
        save(context: context)
        return created
    }

    @discardableResult
    private static func applyLocalDefaultsIfNeeded(to state: SyncedAppSettings) -> Bool {
        var changed = false

        let hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        if state.hasCompletedOnboarding != hasCompletedOnboarding {
            state.hasCompletedOnboarding = hasCompletedOnboarding
            changed = true
        }

        let currentUserID: UUID?
        if let currentUserRaw = defaults.string(forKey: "currentUserID") {
            currentUserID = UUID(uuidString: currentUserRaw)
        } else {
            currentUserID = nil
        }
        if state.currentUserID != currentUserID {
            state.currentUserID = currentUserID
            changed = true
        }

        // Legacy fields remain in the SwiftData schema for lightweight migration,
        // but remote coaching is disabled and its configuration is actively cleared.
        if !state.aiCoachEndpointURL.isEmpty {
            state.aiCoachEndpointURL = ""
            changed = true
        }
        if !state.aiCoachProxyToken.isEmpty {
            state.aiCoachProxyToken = ""
            changed = true
        }

        let localUpdatedAt = defaults.double(forKey: localUpdatedAtKey)
        if localUpdatedAt > 0 {
            let localDate = Date(timeIntervalSince1970: localUpdatedAt)
            if state.updatedAt != localDate {
                state.updatedAt = localDate
                changed = true
            }
        } else if changed {
            state.updatedAt = Date()
        }

        return changed
    }

    private static func apply(state: SyncedAppSettings) {
        defaults.set(state.hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        defaults.set(state.currentUserID?.uuidString, forKey: "currentUserID")
        defaults.removeObject(forKey: "aiCoachEndpointURL")
        defaults.removeObject(forKey: "aiCoachProxyToken")
    }

    private static func save(context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Keep local defaults as source of truth if cloud write fails.
        }
    }
}
