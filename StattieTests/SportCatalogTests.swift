import XCTest
import SwiftData
@testable import Stattie

@MainActor
final class SportCatalogTests: XCTestCase {
    func testCatalogCoversMajorNorthAmericanAndEuropeanSports() {
        let names = Set(SportCatalog.all.map(\.name))
        XCTAssertEqual(names.count, SportCatalog.all.count)
        XCTAssertTrue(names.isSuperset(of: [
            "Basketball", "Soccer", "Ice Hockey", "Baseball", "Softball",
            "American Football", "Canadian Football", "Lacrosse", "Volleyball",
            "Rugby", "Handball", "Field Hockey", "Cricket", "Water Polo",
            "Tennis", "Golf", "Wrestling", "Curling",
        ]))
    }

    func testBasketballAndSoccerStayCustomized() throws {
        let basketball = try XCTUnwrap(SportCatalog.profile(named: "Basketball"))
        let soccer = try XCTUnwrap(SportCatalog.profile(named: "Soccer"))
        XCTAssertTrue(basketball.usesCustomTracking)
        XCTAssertTrue(basketball.usesCustomSeed)
        XCTAssertTrue(soccer.usesCustomTracking)
        XCTAssertTrue(soccer.usesCustomSeed)
        XCTAssertTrue(basketball.stats.isEmpty)
        XCTAssertFalse(soccer.stats.isEmpty)
        XCTAssertTrue(soccer.stats.contains { $0.shortName == "SAV" && $0.roles == [.goalie] })
    }

    func testExistingSoccerAndBasketballPositionRawValuesAreUnchanged() {
        XCTAssertEqual(SoccerPosition.goalkeeper.rawValue, "GK")
        XCTAssertEqual(SoccerPosition.center.rawValue, "C")
        XCTAssertEqual(SoccerPosition.pointGuard.displayName, "Point Guard")
        XCTAssertEqual(SoccerPosition.striker.displayName, "Striker")
        XCTAssertEqual(SoccerPosition.goalkeeper.supportedSport, .soccer)
        XCTAssertEqual(SoccerPosition.center.supportedSport, .basketball)
    }

    func testPositionRawValuesAreUnique() {
        let rawValues = SoccerPosition.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testSportNameResolutionDoesNotDefaultHockeyOrFootballToSoccer() {
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "Ice Hockey"), .iceHockey)
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "Field Hockey"), .fieldHockey)
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "American Football"), .americanFootball)
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "Canadian Football"), .canadianFootball)
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "Soccer"), .soccer)
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "Basketball"), .basketball)
        XCTAssertEqual(SoccerPosition.SupportedSport.from(sportName: "Baseball"), .baseball)
    }

    func testSoccerGoalieAndDefenderSeeDifferentBoards() throws {
        let soccer = try XCTUnwrap(SportCatalog.profile(named: "Soccer"))
        let goalie = Set(soccer.visibleStats(for: [.goalie]).map(\.shortName))
        let defender = Set(soccer.visibleStats(for: [.defense]).map(\.shortName))

        XCTAssertTrue(goalie.contains("SAV"))
        XCTAssertTrue(goalie.contains("GOL"))
        XCTAssertFalse(goalie.contains("TKL"))
        XCTAssertFalse(goalie.contains("SOT"))

        XCTAssertTrue(defender.contains("TKL"))
        XCTAssertTrue(defender.contains("INT"))
        XCTAssertTrue(defender.contains("GOL"))
        XCTAssertFalse(defender.contains("SAV"))

        XCTAssertTrue(SportCatalog.showsStat("SAV", sportName: "Soccer", positions: [.goalkeeper]))
        XCTAssertFalse(SportCatalog.showsStat("SAV", sportName: "Soccer", positions: [.defender]))
        XCTAssertTrue(SportCatalog.showsStat("SAV", sportName: "Soccer", positions: []))
    }

    func testHockeyGoalieSeesSavesAndNotSkaterHits() throws {
        let hockey = try XCTUnwrap(SportCatalog.profile(named: "Ice Hockey"))
        let goalie = Set(hockey.visibleStats(for: [.goalie]).map(\.shortName))
        let skater = Set(hockey.visibleStats(for: [.skater]).map(\.shortName))

        XCTAssertTrue(goalie.contains("SV"))
        XCTAssertTrue(goalie.contains("GA"))
        XCTAssertTrue(goalie.contains("G"))
        XCTAssertFalse(goalie.contains("HIT"))
        XCTAssertFalse(goalie.contains("FO"))

        XCTAssertTrue(skater.contains("G"))
        XCTAssertTrue(skater.contains("HIT"))
        XCTAssertTrue(skater.contains("SOG"))
        XCTAssertFalse(skater.contains("SV"))
    }

    func testBaseballPitcherAndBatterHaveDifferentCoreStats() throws {
        let baseball = try XCTUnwrap(SportCatalog.profile(named: "Baseball"))
        let pitcher = Set(baseball.visibleStats(for: [.pitcher, .batter]).map(\.shortName))
        let batter = Set(baseball.visibleStats(for: [.batter, .fielder]).map(\.shortName))
        let catcher = Set(baseball.visibleStats(for: [.catcher, .batter, .fielder]).map(\.shortName))

        XCTAssertTrue(pitcher.contains("SO"))
        XCTAssertTrue(pitcher.contains("ER"))
        XCTAssertTrue(pitcher.contains("1B"))
        XCTAssertFalse(pitcher.contains("PB"))

        XCTAssertTrue(batter.contains("HR"))
        XCTAssertTrue(batter.contains("RBI"))
        XCTAssertFalse(batter.contains("SO"))
        XCTAssertFalse(batter.contains("ER"))

        XCTAssertTrue(catcher.contains("PB"))
        XCTAssertTrue(catcher.contains("CS"))
        XCTAssertTrue(catcher.contains("HR"))
    }

    func testSoftballSharesDiamondPositionsAndBaseballKeepsDesignatedHitter() {
        let softballPositions = SoccerPosition.positions(for: .softball)
        let baseballPositions = SoccerPosition.positions(for: .baseball)
        XCTAssertTrue(softballPositions.contains(.baseballPitcher))
        XCTAssertTrue(softballPositions.contains(.baseballCatcher))
        XCTAssertFalse(softballPositions.contains(.baseballDesignatedHitter))
        XCTAssertTrue(baseballPositions.contains(.baseballDesignatedHitter))
    }

    func testCanadianFootballIncludesSlotbackAndRouge() throws {
        let canadian = try XCTUnwrap(SportCatalog.profile(named: "Canadian Football"))
        let american = try XCTUnwrap(SportCatalog.profile(named: "American Football"))
        XCTAssertTrue(canadian.stats.contains { $0.shortName == "RG" })
        XCTAssertFalse(american.stats.contains { $0.shortName == "RG" })
        XCTAssertTrue(SoccerPosition.positions(for: .canadianFootball).contains(.footballSlotback))
        XCTAssertFalse(SoccerPosition.positions(for: .americanFootball).contains(.footballSlotback))
        XCTAssertTrue(SoccerPosition.positions(for: .americanFootball).contains(.footballTE))
    }

    func testMultiplePositionsUnionStatRoles() throws {
        let assignments = PositionAssignments(assignments: [
            PositionAssignment(position: .hockeyGoalie, percentage: 60),
            PositionAssignment(position: .hockeyForward, percentage: 40),
        ])
        XCTAssertTrue(assignments.includesGoalkeeper)
        XCTAssertEqual(assignments.statRoles, [.goalie, .skater])

        let hockey = try XCTUnwrap(SportCatalog.profile(named: "Ice Hockey"))
        let visible = Set(hockey.visibleStats(for: assignments.statRoles).map(\.shortName))
        XCTAssertTrue(visible.contains("SV"))
        XCTAssertTrue(visible.contains("HIT"))
    }

    func testSeedingCreatesNewSportsWithoutChangingBasketballAndSoccerPresets() throws {
        let schema = Schema([
            Sport.self,
            StatDefinition.self,
            Game.self,
            Person.self,
            Team.self,
            TeamMembership.self,
            PersonGameStats.self,
            Stat.self,
            Shift.self,
            ShiftStat.self,
            User.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        SeedDataService.shared.seedAllSportsIfNeeded(context: context)

        let sports = try context.fetch(FetchDescriptor<Sport>())
        let names = Set(sports.map(\.name))
        XCTAssertTrue(names.isSuperset(of: [
            "Basketball", "Soccer", "Ice Hockey", "Baseball", "American Football",
            "Canadian Football", "Lacrosse", "Rugby", "Handball",
        ]))

        let basketball = try XCTUnwrap(sports.first { $0.name == "Basketball" })
        let soccer = try XCTUnwrap(sports.first { $0.name == "Soccer" })
        let hockey = try XCTUnwrap(sports.first { $0.name == "Ice Hockey" })
        let baseball = try XCTUnwrap(sports.first { $0.name == "Baseball" })

        XCTAssertEqual(Set((basketball.statDefinitions ?? []).map(\.shortName)), [
            "2PT", "3PT", "FT", "DREB", "OREB", "STL", "AST", "PF", "TO",
            "MD", "SD", "BPO", "BPD", "GPO", "GPD",
        ])
        XCTAssertEqual(Set((soccer.statDefinitions ?? []).map(\.shortName)), [
            "GOL", "SOT", "AST", "PAS", "TKL", "INT", "SAV", "FLS", "YC", "RC", "CRN",
        ])
        XCTAssertTrue((hockey.statDefinitions ?? []).contains { $0.shortName == "SV" })
        XCTAssertTrue((baseball.statDefinitions ?? []).contains { $0.shortName == "SO" })
        XCTAssertTrue((baseball.statDefinitions ?? []).contains { $0.shortName == "HR" })
        XCTAssertTrue(hockey.isTeamSport)
        XCTAssertTrue(sports.first { $0.name == "Tennis" }?.isTeamSport == false)
        XCTAssertTrue(sports.first { $0.name == "Wrestling" }?.isTeamSport == false)
    }
}
