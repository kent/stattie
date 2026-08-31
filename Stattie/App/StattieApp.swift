import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct StattieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Person.self,
            Team.self,
            TeamMembership.self,
            Sport.self,
            StatDefinition.self,
            Game.self,
            PersonGameStats.self,
            Stat.self,
            Shift.self,
            ShiftStat.self,
            SyncedAppSettings.self,
            SyncedAchievementState.self
        ])

        // Bind explicitly to the production container so diagnostics and
        // NSPersistentCloudKitContainer export the same private database.
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(CloudKitContainerProvider.shared.containerIdentifier)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudKitConfig])
            SharedModelContainer.isCloudKitBacked = true
            return container
        } catch {
            // CloudKit not available, use local storage only
            print("CloudKit not available, using local storage: \(error)")
            SharedModelContainer.isCloudKitBacked = false
        }

        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        SharedModelContainer.container = sharedModelContainer
        do {
            _ = try StatAttributionMigration.migrateLegacyShiftStats(
                in: sharedModelContainer.mainContext
            )
        } catch {
            // GameTrackingView retries and presents a visible error if launch-time
            // migration could not be committed.
            print("Stat attribution migration failed: \(error.localizedDescription)")
        }
        do {
            _ = try PlayerPhotoStore.migrateOversizedPhotos(
                in: sharedModelContainer.mainContext
            )
        } catch {
            print("Player photo compression failed: \(error.localizedDescription)")
        }
        CloudSyncedPreferences.bootstrapIfNeeded(force: true)
        AchievementManager.shared.synchronizeFromCloud()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App Delegate for Quick Actions

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var shortcutAction: String?

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Handle quick action if app was launched via shortcut
        if let shortcutItem = options.shortcutItem {
            AppDelegate.shortcutAction = shortcutItem.type
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        return config
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.setNotificationCategories([])

        // Register quick actions
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.stattie.newgame",
                localizedTitle: "New Game",
                localizedSubtitle: "Start tracking a game",
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "com.stattie.players",
                localizedTitle: "Players",
                localizedSubtitle: "View your players",
                icon: UIApplicationShortcutIcon(systemImageName: "person.3.fill"),
                userInfo: nil
            )
        ]
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        AppDelegate.shortcutAction = shortcutItem.type
        completionHandler(true)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
