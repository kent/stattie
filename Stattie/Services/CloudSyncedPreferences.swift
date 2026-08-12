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
        applyLocalDefaults(to: state)
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
        save(context: context)
        return created
    }

    private static func applyLocalDefaults(to state: SyncedAppSettings) {
        state.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if let currentUserRaw = defaults.string(forKey: "currentUserID"),
           let currentUserID = UUID(uuidString: currentUserRaw) {
            state.currentUserID = currentUserID
        } else {
            state.currentUserID = nil
        }

        // Legacy fields remain in the SwiftData schema for lightweight migration,
        // but remote coaching is disabled and its configuration is actively cleared.
        state.aiCoachEndpointURL = ""
        state.aiCoachProxyToken = ""

        let localUpdatedAt = defaults.double(forKey: localUpdatedAtKey)
        if localUpdatedAt > 0 {
            state.updatedAt = Date(timeIntervalSince1970: localUpdatedAt)
        } else {
            state.updatedAt = Date()
        }
    }

    private static func apply(state: SyncedAppSettings) {
        defaults.set(state.hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        defaults.set(state.currentUserID?.uuidString, forKey: "currentUserID")
        defaults.removeObject(forKey: "aiCoachEndpointURL")
        defaults.removeObject(forKey: "aiCoachProxyToken")
    }

    private static func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            // Keep local defaults as source of truth if cloud write fails.
        }
    }
}
