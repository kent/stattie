import XCTest
@testable import Stattie

final class AchievementTests: XCTestCase {
    func testVisibleCatalogKeepsBadgesAndHidesStreaks() {
        let visible = Set(AchievementType.visibleCases)

        XCTAssertTrue(visible.contains(.firstGame))
        XCTAssertTrue(visible.contains(.tenGames))
        XCTAssertTrue(visible.contains(.fiftyGames))
        XCTAssertTrue(visible.contains(.hundredGames))
        XCTAssertTrue(visible.contains(.twentyPoints))
        XCTAssertTrue(visible.contains(.thirtyPoints))
        XCTAssertTrue(visible.contains(.fiftyPoints))
        XCTAssertTrue(visible.contains(.doubleDouble))
        XCTAssertTrue(visible.contains(.tripleDouble))
        XCTAssertTrue(visible.contains(.hatTrick))
        XCTAssertTrue(visible.contains(.cleanSheet))
        XCTAssertTrue(visible.contains(.firstShare))

        XCTAssertFalse(visible.contains(.threeDayStreak))
        XCTAssertFalse(visible.contains(.sevenDayStreak))
        XCTAssertFalse(visible.contains(.thirtyDayStreak))
        XCTAssertFalse(visible.contains(.sharedPlayer))
        XCTAssertEqual(visible.count, AchievementType.allCases.filter(\.isVisibleInCatalog).count)
    }

    func testLegacyStreakAchievementIDsStillDecode() {
        XCTAssertEqual(AchievementType(rawValue: "three_day_streak"), .threeDayStreak)
        XCTAssertEqual(AchievementType(rawValue: "seven_day_streak"), .sevenDayStreak)
        XCTAssertEqual(AchievementType(rawValue: "thirty_day_streak"), .thirtyDayStreak)
    }
}
