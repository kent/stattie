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
            SyncedAchievementState.self,
            SyncedAICacheEntry.self
        ])

        // Try CloudKit first, fall back to local-only if not available
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
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
        CloudSyncedPreferences.bootstrapIfNeeded(force: true)
        AchievementManager.shared.synchronizeFromCloud(force: true)
        LocalCoachingService.shared.bootstrapCloudCacheIfNeeded()
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
        registerNotificationCategories()

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

    private func registerNotificationCategories() {
        let openAcademyAction = UNNotificationAction(
            identifier: "OPEN_ACADEMY",
            title: "Open Academy",
            options: [.foreground]
        )

        let academyReadyCategory = UNNotificationCategory(
            identifier: "ACADEMY_READY",
            actions: [openAcademyAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([academyReadyCategory])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let destination = userInfo["destination"] as? String

        if destination == "academy" {
            let playerIDRaw = userInfo["playerID"] as? String
            let playerID = playerIDRaw.flatMap(UUID.init(uuidString:))

            DispatchQueue.main.async {
                AppState.shared.navigateToAcademy(playerID: playerID)
            }
        }

        completionHandler()
    }
}
