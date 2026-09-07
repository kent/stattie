import XCTest
import SwiftData
import UIKit
import CloudKit
import CoreData
@testable import Stattie

@MainActor
final class CloudKitSyncTests: XCTestCase {
    private var previousContainer: ModelContainer?
    private var previousUserID: UUID?

    override func setUp() {
        super.setUp()
        previousContainer = SharedModelContainer.container
        previousUserID = AppState.shared.currentUserID
    }

    override func tearDown() {
        SharedModelContainer.container = previousContainer
        AppState.shared.currentUserID = previousUserID
        super.tearDown()
    }

    func testPreparedPhotoIsSmallerThanCloudKitRecordLimit() {
        let original = stripedJPEG(width: 2400, height: 2400, quality: 1)
        XCTAssertGreaterThan(original.count, PlayerPhotoStore.maxByteCount)

        let prepared = try? XCTUnwrap(PlayerPhotoStore.preparedData(from: original))
        XCTAssertNotNil(prepared)
        XCTAssertLessThanOrEqual(prepared?.count ?? .max, PlayerPhotoStore.maxByteCount)
        XCTAssertNotNil(prepared.flatMap(UIImage.init(data:)))
    }

    func testPreparedPhotoUsesPixelCapIndependentOfDisplayScale() throws {
        let original = stripedJPEG(width: 1200, height: 800, quality: 1)
        let prepared = try XCTUnwrap(PlayerPhotoStore.preparedData(from: original))
        let image = try XCTUnwrap(UIImage(data: prepared)?.cgImage)
        XCTAssertLessThanOrEqual(max(image.width, image.height), Int(PlayerPhotoStore.maxPixelSize))
        XCTAssertEqual(PlayerPhotoStore.preparedData(from: prepared), prepared)
    }

    func testSmallPhotosAreLeftAloneWhenAlreadyUnderTheCap() {
        let original = stripedJPEG(width: 64, height: 64, quality: 0.8)
        XCTAssertLessThanOrEqual(original.count, PlayerPhotoStore.maxByteCount)

        let prepared = PlayerPhotoStore.preparedData(from: original)
        XCTAssertEqual(prepared, original)
    }

    func testUnreadableOversizedPayloadIsDropped() {
        let junk = Data(repeating: 7, count: PlayerPhotoStore.maxByteCount + 12)
        XCTAssertNil(PlayerPhotoStore.preparedData(from: junk))
    }

    func testLaunchMigrationRewritesOversizedPlayerPhotos() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = stripedJPEG(width: 2200, height: 2200, quality: 1)
        XCTAssertGreaterThan(original.count, PlayerPhotoStore.maxByteCount)

        let player = Person(firstName: "Maya", lastName: "Chen", photoData: original)
        context.insert(player)
        try context.save()

        let rewritten = try PlayerPhotoStore.migrateOversizedPhotos(in: context)
        XCTAssertEqual(rewritten, 1)
        XCTAssertLessThanOrEqual(player.photoData?.count ?? .max, PlayerPhotoStore.maxByteCount)
        XCTAssertFalse(context.hasChanges)
    }

    func testPartialFailureWithoutNestedErrorsGetsAReadableMessage() {
        let error = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)"]
        )
        let message = CloudKitErrorFormatter.userFacingMessage(for: error)
        XCTAssertTrue(message.contains("Some records could not be uploaded"))
        XCTAssertFalse(message.contains("CKErrorDomain error 2"))
    }

    func testPartialFailureSurfacesNestedLimitExceeded() {
        let nested = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.limitExceeded.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Limit exceeded"]
        )
        let error = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)",
                CKPartialErrorsByItemIDKey: ["record-1": nested]
            ]
        )
        let message = CloudKitErrorFormatter.userFacingMessage(for: error)
        XCTAssertTrue(message.contains("too large"))
        XCTAssertFalse(message.contains("CKErrorDomain error 2"))
    }

    func testQuotaExceededUsesStorageMessage() {
        let error = NSError(
            domain: CKError.errorDomain,
            code: CKError.Code.quotaExceeded.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Quota exceeded"]
        )
        XCTAssertEqual(
            CloudKitErrorFormatter.userFacingMessage(for: error),
            "This iCloud account is out of storage."
        )
    }

    func testReseedingSportsDoesNotDirtyUnchangedRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext

        SeedDataService.shared.seedBasketballIfNeeded(context: context)
        XCTAssertFalse(context.hasChanges)

        SeedDataService.shared.seedBasketballIfNeeded(context: context)
        XCTAssertFalse(context.hasChanges)

        let sports = try context.fetch(FetchDescriptor<Sport>())
        XCTAssertEqual(sports.filter { $0.name == "Basketball" }.count, 1)
    }

    func testRestoredProfileWorksWithoutCloudPreferenceRows() throws {
        let container = try makeContainer()
        SharedModelContainer.container = container
        AppState.shared.currentUserID = nil
        let restored = User(displayName: "Restored")
        container.mainContext.insert(restored)
        try container.mainContext.save()

        let users = try container.mainContext.fetch(FetchDescriptor<User>())
        XCTAssertEqual(users.resolvedCurrentUser?.id, restored.id)
        _ = AppState.shared.currentUserID
        _ = AppState.shared.hasCompletedOnboarding
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<SyncedAppSettings>()).isEmpty)
        XCTAssertFalse(container.mainContext.hasChanges)
        XCTAssertNil(AppState.shared.currentUserID, "Resolving a view must not mutate preferences")
    }

    func testStaleProfilePreferenceFallsBackDeterministically() {
        AppState.shared.currentUserID = UUID()
        let older = User(displayName: "Older")
        let newer = User(displayName: "Newer")
        older.createdAt = Date(timeIntervalSince1970: 1)
        newer.createdAt = Date(timeIntervalSince1970: 2)
        XCTAssertEqual([newer, older].resolvedCurrentUser?.id, older.id)
    }

    func testConcurrentAchievementSnapshotsMergeWithoutRewritingCloudRows() throws {
        let container = try makeContainer()
        SharedModelContainer.container = container
        let ownerID = UUID()
        AppState.shared.currentUserID = ownerID
        let suite = "StattieSyncTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = AchievementManager(defaults: defaults)
        let first = SyncedAchievementState(ownerUserID: ownerID)
        first.unlockedAchievementIDsJSON = "[\"first_game\"]"
        first.totalPoints = 500 // Includes preserved legacy points.
        first.updatedAt = Date(timeIntervalSince1970: 10)
        let second = SyncedAchievementState(ownerUserID: ownerID)
        second.unlockedAchievementIDsJSON = "[\"hat_trick\"]"
        second.updatedAt = Date(timeIntervalSince1970: 5)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()

        manager.synchronizeFromCloud()
        XCTAssertEqual(manager.unlockedAchievements, [.firstGame, .hatTrick])
        XCTAssertEqual(manager.totalPoints, 500 + AchievementType.hatTrick.points)
        manager.synchronizeFromCloud()
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SyncedAchievementState>()), 2)
        XCTAssertEqual(second.updatedAt, Date(timeIntervalSince1970: 5))
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testLegacyAchievementsMigrateOnceAndOfflineUnlockSurvives() throws {
        let container = try makeContainer()
        SharedModelContainer.container = container
        let ownerID = UUID()
        AppState.shared.currentUserID = ownerID
        let suite = "StattieSyncTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(["first_game"]), forKey: "unlockedAchievements")
        defaults.set(500, forKey: "achievementPoints")
        let manager = AchievementManager(defaults: defaults)
        manager.synchronizeFromCloud()
        manager.synchronizeFromCloud()
        XCTAssertEqual(manager.totalPoints, 500)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SyncedAchievementState>()), 1)

        SharedModelContainer.container = nil
        XCTAssertTrue(manager.unlock(.hatTrick))
        XCTAssertFalse(manager.unlock(.hatTrick))
        SharedModelContainer.container = container
        manager.synchronizeFromCloud()
        XCTAssertEqual(manager.unlockedAchievements, [.firstGame, .hatTrick])
        XCTAssertEqual(manager.totalPoints, 500 + AchievementType.hatTrick.points)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SyncedAchievementState>()), 2)

        AppState.shared.currentUserID = UUID()
        manager.synchronizeFromCloud()
        XCTAssertTrue(manager.unlockedAchievements.isEmpty)
        XCTAssertEqual(manager.totalPoints, 0)
    }

    func testReadingAchievementsDoesNotCreateEmptyCloudSnapshots() throws {
        let container = try makeContainer()
        SharedModelContainer.container = container
        AppState.shared.currentUserID = UUID()
        let suite = "StattieSyncTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = AchievementManager(defaults: defaults)
        manager.synchronizeFromCloud()
        _ = manager.unlockedAchievements
        _ = manager.totalPoints
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SyncedAchievementState>()), 0)
    }

    func testAvailableAccountDoesNotClaimEveryRecordHasSynced() {
        var activity = SyncActivity()
        activity.record(id: UUID(), type: .export, endDate: Date(), succeeded: true, errorMessage: nil)
        let status = SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .available, activity: activity)
        XCTAssertEqual(status.headline, "iCloud sync is on")
        XCTAssertFalse(status.isActive)
        XCTAssertFalse(status.needsAttention)
    }

    func testSetupDoesNotCountAsDataTransfer() {
        var activity = SyncActivity()
        activity.record(id: UUID(), type: .setup, endDate: Date(), succeeded: true, errorMessage: nil)
        XCTAssertNil(activity.lastTransferDate)
    }

    func testOverlappingOperationsStayActiveUntilBothEnd() {
        var activity = SyncActivity()
        let first = UUID()
        let second = UUID()
        activity.record(id: first, type: .export, endDate: nil, succeeded: false, errorMessage: nil)
        activity.record(id: second, type: .export, endDate: nil, succeeded: false, errorMessage: nil)
        activity.record(id: first, type: .export, endDate: Date(), succeeded: true, errorMessage: nil)
        XCTAssertTrue(SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .available, activity: activity).isActive)
        activity.record(id: second, type: .export, endDate: Date(), succeeded: true, errorMessage: nil)
        XCTAssertFalse(SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .available, activity: activity).isActive)
    }

    func testSuccessfulDownloadDoesNotHideFailedUpload() {
        var activity = SyncActivity()
        activity.record(id: UUID(), type: .export, endDate: Date(), succeeded: false, errorMessage: "Out of storage.")
        activity.record(id: UUID(), type: .import, endDate: Date(), succeeded: true, errorMessage: nil)
        let status = SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .available, activity: activity)
        XCTAssertTrue(status.needsAttention)
        XCTAssertTrue(status.detail.contains("Out of storage."))
        activity.record(id: UUID(), type: .export, endDate: Date(), succeeded: true, errorMessage: nil)
        XCTAssertFalse(SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .available, activity: activity).needsAttention)
    }

    func testUnsuccessfulEventWithoutErrorIsNotReportedAsSuccess() {
        var activity = SyncActivity()
        activity.record(id: UUID(), type: .export, endDate: Date(), succeeded: false, errorMessage: nil)
        XCTAssertNil(activity.lastTransferDate)
        XCTAssertTrue(SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .available, activity: activity).needsAttention)
    }

    func testSignedOutStatusExplainsAutomaticSyncAndLocalStorage() {
        let status = SyncStatus.snapshot(isCloudKitBacked: true, accountStatus: .noAccount)
        XCTAssertEqual(status.headline, "Saved on this iPhone")
        XCTAssertTrue(status.detail.contains("sync automatically"))
        XCTAssertFalse(status.isActive)
    }

    func testLocalFallbackNeverClaimsCloudSyncIsOn() {
        let status = SyncStatus.snapshot(isCloudKitBacked: false, accountStatus: .available)
        XCTAssertEqual(status.headline, "Saved on this iPhone")
        XCTAssertTrue(status.needsAttention)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = SharedModelContainer.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func stripedJPEG(width: Int, height: Int, quality: CGFloat) -> Data {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cell = 6
            for y in stride(from: 0, to: height, by: cell) {
                for x in stride(from: 0, to: width, by: cell) {
                    UIColor(
                        red: CGFloat((x * 13) % 255) / 255,
                        green: CGFloat((y * 17) % 255) / 255,
                        blue: CGFloat((x + y) % 255) / 255,
                        alpha: 1
                    ).setFill()
                    context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
        }
        return image.jpegData(compressionQuality: quality) ?? Data()
    }
}
