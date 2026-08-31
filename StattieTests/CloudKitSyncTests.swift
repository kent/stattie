import XCTest
import SwiftData
import UIKit
import CloudKit
@testable import Stattie

@MainActor
final class CloudKitSyncTests: XCTestCase {
    private var previousContainer: ModelContainer?

    override func setUp() {
        super.setUp()
        previousContainer = SharedModelContainer.container
    }

    override func tearDown() {
        SharedModelContainer.container = previousContainer
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: "currentUserID")
        defaults.removeObject(forKey: "cloudSyncedPreferencesLocalUpdatedAt")
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

    func testPreferenceSyncDoesNotRewriteUnchangedCloudState() throws {
        let container = try makeContainer()
        SharedModelContainer.container = container
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(UUID().uuidString, forKey: "currentUserID")
        defaults.removeObject(forKey: "cloudSyncedPreferencesLocalUpdatedAt")

        CloudSyncedPreferences.synchronizeFromCloudIfAvailable()
        let first = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SyncedAppSettings>()).first)
        let firstUpdatedAt = first.updatedAt

        CloudSyncedPreferences.synchronizeFromCloudIfAvailable()
        let second = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SyncedAppSettings>()).first)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.updatedAt, firstUpdatedAt)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testHealthySyncProgressFillsConnectDownloadUpload() {
        let now = Date()
        let uploadedAt = now.addingTimeInterval(-90)
        let progress = SyncProgress.snapshot(
            isCloudKitBacked: true,
            accountStatus: .available,
            isCheckingStatus: false,
            isRetryPending: false,
            inFlightPhases: [],
            completedDates: [.upload: uploadedAt],
            failedPhase: nil,
            errorMessage: nil,
            lastSyncDate: uploadedAt,
            now: now
        )

        XCTAssertEqual(progress.headline, "iCloud is healthy")
        XCTAssertEqual(progress.status(for: .setup), .complete)
        XCTAssertEqual(progress.status(for: .download), .complete)
        XCTAssertEqual(progress.status(for: .upload), .complete)
        XCTAssertEqual(progress.overallFraction, 1)
        XCTAssertFalse(progress.showsRetry)
        XCTAssertFalse(progress.isActive)
        XCTAssertTrue(progress.detail.contains("Uploaded"))
        XCTAssertFalse(progress.detail.localizedCaseInsensitiveContains("retry"))
    }

    func testUploadInFlightAdvancesThematicProgress() {
        let now = Date()
        let progress = SyncProgress.snapshot(
            isCloudKitBacked: true,
            accountStatus: .available,
            isCheckingStatus: false,
            isRetryPending: false,
            inFlightPhases: [.upload],
            completedDates: [
                .setup: now.addingTimeInterval(-20),
                .download: now.addingTimeInterval(-10)
            ],
            failedPhase: nil,
            errorMessage: nil,
            lastSyncDate: now.addingTimeInterval(-10),
            now: now
        )

        XCTAssertEqual(progress.headline, "Uploading players and games")
        XCTAssertEqual(progress.status(for: .setup), .complete)
        XCTAssertEqual(progress.status(for: .download), .complete)
        XCTAssertEqual(progress.status(for: .upload), .active)
        XCTAssertTrue(progress.isActive)
        XCTAssertGreaterThan(progress.overallFraction, 0.6)
        XCTAssertLessThan(progress.overallFraction, 1)
        XCTAssertFalse(progress.showsRetry)
    }

    func testFailedUploadKeepsEarlierPhasesAndOffersRetry() {
        let now = Date()
        let progress = SyncProgress.snapshot(
            isCloudKitBacked: true,
            accountStatus: .available,
            isCheckingStatus: false,
            isRetryPending: false,
            inFlightPhases: [],
            completedDates: [
                .setup: now.addingTimeInterval(-40),
                .download: now.addingTimeInterval(-20)
            ],
            failedPhase: .upload,
            errorMessage: "Some records could not be uploaded to iCloud.",
            lastSyncDate: now.addingTimeInterval(-20),
            now: now
        )

        XCTAssertEqual(progress.headline, "Couldn’t finish upload")
        XCTAssertEqual(progress.status(for: .setup), .complete)
        XCTAssertEqual(progress.status(for: .download), .complete)
        XCTAssertEqual(progress.status(for: .upload), .failed)
        XCTAssertEqual(progress.errorMessage, "Some records could not be uploaded to iCloud.")
        XCTAssertTrue(progress.showsRetry)
        XCTAssertFalse(progress.isActive)
    }

    func testRetryPendingShowsSyncingInsteadOfRetryOperation() {
        let progress = SyncProgress.snapshot(
            isCloudKitBacked: true,
            accountStatus: .available,
            isCheckingStatus: false,
            isRetryPending: true,
            inFlightPhases: [],
            completedDates: [:],
            failedPhase: nil,
            errorMessage: nil,
            lastSyncDate: nil
        )

        XCTAssertEqual(progress.headline, "Syncing with iCloud")
        XCTAssertTrue(progress.isActive)
        XCTAssertFalse(progress.showsRetry)
        XCTAssertFalse(progress.headline.localizedCaseInsensitiveContains("retry"))
        XCTAssertGreaterThan(progress.overallFraction, 0)
    }

    func testSignedOutProgressAsksForiCloudSignIn() {
        let progress = SyncProgress.snapshot(
            isCloudKitBacked: true,
            accountStatus: .noAccount,
            isCheckingStatus: false,
            isRetryPending: false,
            inFlightPhases: [],
            completedDates: [:],
            failedPhase: nil,
            errorMessage: nil,
            lastSyncDate: nil
        )

        XCTAssertEqual(progress.headline, "Sign in to iCloud")
        XCTAssertEqual(progress.status(for: .setup), .waiting)
        XCTAssertEqual(progress.overallFraction, 0)
        XCTAssertFalse(progress.showsRetry)
    }

    private func makeContainer() throws -> ModelContainer {
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
