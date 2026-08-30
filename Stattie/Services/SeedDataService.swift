import Foundation
import SwiftData

final class SeedDataService {
    static let shared = SeedDataService()

    private init() {}

    private var shouldSeedFenwickData: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private typealias StatSeed = (
        name: String,
        shortName: String,
        category: String,
        hasMadeAndMissed: Bool,
        pointValue: Int,
        sortOrder: Int,
        iconName: String
    )

    private struct AggregateCounts {
        var pointValue: Int
        var made: Int = 0
        var missed: Int = 0
        var count: Int = 0
    }

    private struct BasketballPlayerLine {
        let playerKey: String
        let twoMade: Int
        let twoMissed: Int
        let threeMade: Int
        let threeMissed: Int
        let freeThrowMade: Int
        let freeThrowMissed: Int
        let defensiveRebounds: Int
        let offensiveRebounds: Int
        let assists: Int
        let steals: Int
        let fouls: Int
    }

    private struct SoccerPlayerLine {
        let playerKey: String
        let goals: Int
        let shotsOnTargetMade: Int
        let shotsOnTargetMissed: Int
        let assists: Int
        let passes: Int
        let tackles: Int
        let interceptions: Int
        let saves: Int
        let fouls: Int
        let yellowCards: Int
        let redCards: Int
        let corners: Int
    }

    private struct ShiftSeed {
        let startTeamScore: Int
        let startOpponentScore: Int
        let endTeamScore: Int
        let endOpponentScore: Int
        let durationMinutes: Int
    }

    private let showcaseMarkerTeamName = "Lincoln Lions"
    private let showcaseTeamNames: Set<String> = [
        "Lincoln Lions",
        "Bay City United",
        "Metro Tigers"
    ]
    private let showcaseKnownOpponents: Set<String> = [
        "River City Raptors",
        "Northport FC"
    ]
    private let fenwickHistoryTag = "[FenwickHistory]"
    private let fenwickHistoryGamesPerPlayer = 7

    private let basketballStatDefinitions: [StatSeed] = [
        ("2-Point Shot", "2PT", "shooting", true, 2, 0, "basketball.fill"),
        ("3-Point Shot", "3PT", "shooting", true, 3, 1, "basketball.fill"),
        ("Free Throw", "FT", "shooting", true, 1, 2, "basketball.fill"),
        ("Defensive Rebound", "DREB", "rebounding", false, 0, 3, "arrow.down.circle.fill"),
        ("Offensive Rebound", "OREB", "rebounding", false, 0, 4, "arrow.up.circle.fill"),
        ("Steal", "STL", "defense", false, 0, 5, "hand.raised.fill"),
        ("Assist", "AST", "offense", false, 0, 6, "arrow.triangle.branch"),
        ("Foul", "PF", "other", false, 0, 7, "exclamationmark.triangle.fill"),
        ("Turnover", "TO", "other", false, 0, 8, "arrow.uturn.backward.circle.fill"),
        ("Missed Drive", "MD", "offense", false, 0, 9, "xmark.circle.fill"),
        ("Successful Drive", "SD", "offense", false, 0, 10, "checkmark.circle.fill"),
        ("Bad Play Offense", "BPO", "offense", false, 0, 11, "arrow.down.circle"),
        ("Bad Play Defense", "BPD", "defense", false, 0, 12, "shield.lefthalf.filled.slash"),
        ("Great Play Offense", "GPO", "offense", false, 0, 13, "sparkles"),
        ("Great Play Defense", "GPD", "defense", false, 0, 14, "shield.fill"),
    ]

    private let soccerStatDefinitions: [StatSeed] = [
        ("Goal", "GOL", "shooting", false, 1, 0, "soccerball"),
        ("Shot on Target", "SOT", "shooting", true, 0, 1, "scope"),
        ("Assist", "AST", "offense", false, 0, 2, "arrow.triangle.branch"),
        ("Pass", "PAS", "offense", false, 0, 3, "arrow.right"),
        ("Tackle", "TKL", "defense", false, 0, 4, "figure.fall"),
        ("Interception", "INT", "defense", false, 0, 5, "hand.raised.fill"),
        ("Save", "SAV", "defense", false, 0, 6, "hand.raised.square.fill"),
        ("Foul", "FLS", "other", false, 0, 7, "exclamationmark.triangle.fill"),
        ("Yellow Card", "YC", "other", false, 0, 8, "rectangle.fill"),
        ("Red Card", "RC", "other", false, 0, 9, "rectangle.fill"),
        ("Corner", "CRN", "other", false, 0, 10, "arrow.turn.up.right"),
    ]

    private let tennisStatDefinitions: [StatSeed] = [
        ("Ace", "ACE", "serve", false, 0, 0, "bolt.fill"),
        ("Double Fault", "DF", "serve", false, 0, 1, "exclamationmark.triangle.fill"),
        ("First Serve", "FS", "serve", true, 0, 2, "arrow.up.circle.fill"),
        ("Winner", "WIN", "offense", false, 0, 3, "star.fill"),
        ("Unforced Error", "UE", "other", false, 0, 4, "xmark.circle.fill"),
        ("Break Point", "BP", "other", false, 0, 5, "flag.fill"),
    ]

    private let golfStatDefinitions: [StatSeed] = [
        ("Fairway Hit", "FWY", "tee", true, 0, 0, "arrow.right.circle.fill"),
        ("Green in Regulation", "GIR", "approach", true, 0, 1, "flag.fill"),
        ("Putt", "PUT", "green", false, 0, 2, "circle.fill"),
        ("Sand Save", "SND", "short", true, 0, 3, "square.fill"),
        ("Penalty", "PEN", "other", false, 0, 4, "exclamationmark.octagon.fill"),
        ("Birdie", "BRD", "scoring", false, 0, 5, "arrow.down.circle.fill"),
        ("Par", "PAR", "scoring", false, 0, 6, "equal.circle.fill"),
        ("Bogey", "BOG", "scoring", false, 0, 7, "arrow.up.circle.fill"),
    ]

    var shouldSeedShowcaseData: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        ProcessInfo.processInfo.arguments.contains("-seed-showcase-data")
        #endif
    }

    // MARK: - Sports Seeding

    func seedBasketballIfNeeded(context: ModelContext) {
        let basketball = fetchSport(named: "Basketball", context: context) ?? {
            let created = Sport(name: "Basketball", iconName: "basketball.fill", isBuiltIn: true)
            context.insert(created)
            return created
        }()

        basketball.iconName = "basketball.fill"
        basketball.isBuiltIn = true
        basketball.isTeamSport = true
        ensureStatDefinitions(for: basketball, from: basketballStatDefinitions, context: context)

        do {
            try context.save()
            print("Basketball sport seeded successfully")
        } catch {
            print("Failed to save basketball sport: \(error)")
        }
    }

    func seedSoccerIfNeeded(context: ModelContext) {
        let soccer = fetchSport(named: "Soccer", context: context) ?? {
            let created = Sport(name: "Soccer", iconName: "soccerball", isBuiltIn: true)
            context.insert(created)
            return created
        }()

        soccer.iconName = "soccerball"
        soccer.isBuiltIn = true
        soccer.isTeamSport = true
        ensureStatDefinitions(for: soccer, from: soccerStatDefinitions, context: context)

        do {
            try context.save()
            print("Soccer sport seeded successfully")
        } catch {
            print("Failed to save soccer sport: \(error)")
        }
    }

    func seedTennisIfNeeded(context: ModelContext) {
        let tennis = fetchSport(named: "Tennis", context: context) ?? {
            let created = Sport(name: "Tennis", iconName: "tennisball.fill", isBuiltIn: true, isTeamSport: false)
            context.insert(created)
            return created
        }()

        tennis.iconName = "tennisball.fill"
        tennis.isBuiltIn = true
        tennis.isTeamSport = false
        ensureStatDefinitions(for: tennis, from: tennisStatDefinitions, context: context)

        do {
            try context.save()
            print("Tennis sport seeded successfully")
        } catch {
            print("Failed to save tennis sport: \(error)")
        }
    }

    func seedGolfIfNeeded(context: ModelContext) {
        let golf = fetchSport(named: "Golf", context: context) ?? {
            let created = Sport(name: "Golf", iconName: "figure.golf", isBuiltIn: true, isTeamSport: false)
            context.insert(created)
            return created
        }()

        golf.iconName = "figure.golf"
        golf.isBuiltIn = true
        golf.isTeamSport = false
        ensureStatDefinitions(for: golf, from: golfStatDefinitions, context: context)

        do {
            try context.save()
            print("Golf sport seeded successfully")
        } catch {
            print("Failed to save golf sport: \(error)")
        }
    }

    func getBasketball(context: ModelContext) -> Sport? {
        fetchSport(named: "Basketball", context: context)
    }

    func getSoccer(context: ModelContext) -> Sport? {
        fetchSport(named: "Soccer", context: context)
    }

    func getTennis(context: ModelContext) -> Sport? {
        fetchSport(named: "Tennis", context: context)
    }

    func getGolf(context: ModelContext) -> Sport? {
        fetchSport(named: "Golf", context: context)
    }

    func seedAllSportsIfNeeded(context: ModelContext) {
        seedBasketballIfNeeded(context: context)
        seedSoccerIfNeeded(context: context)
        seedTennisIfNeeded(context: context)
        seedGolfIfNeeded(context: context)
        seedCatalogSportsIfNeeded(context: context)
    }

    func seedSelectedSports(_ names: Set<String>, context: ModelContext) {
        for name in names {
            seedSport(named: name, context: context)
        }
    }

    func seedSport(named name: String, context: ModelContext) {
        switch name {
        case "Basketball":
            seedBasketballIfNeeded(context: context)
        case "Soccer":
            seedSoccerIfNeeded(context: context)
        case "Tennis":
            seedTennisIfNeeded(context: context)
        case "Golf":
            seedGolfIfNeeded(context: context)
        default:
            guard let profile = SportCatalog.profile(named: name), !profile.usesCustomSeed else { return }
            seedCatalogSport(profile, context: context)
        }
    }

    func seedCatalogSportsIfNeeded(context: ModelContext) {
        for profile in SportCatalog.seedableSports {
            seedCatalogSport(profile, context: context)
        }
    }

    private func seedCatalogSport(_ profile: SportProfile, context: ModelContext) {
        let sport = fetchSport(named: profile.name, context: context) ?? {
            let created = Sport(
                name: profile.name,
                iconName: profile.iconName,
                isBuiltIn: true,
                isTeamSport: profile.isTeamSport
            )
            context.insert(created)
            return created
        }()

        sport.iconName = profile.iconName
        sport.isBuiltIn = true
        sport.isTeamSport = profile.isTeamSport
        ensureStatDefinitions(for: sport, from: profile.stats.map { spec in
            (
                name: spec.name,
                shortName: spec.shortName,
                category: spec.category,
                hasMadeAndMissed: spec.hasMadeAndMissed,
                pointValue: spec.pointValue,
                sortOrder: spec.sortOrder,
                iconName: spec.iconName
            )
        }, context: context)

        do {
            try context.save()
            print("\(profile.name) sport seeded successfully")
        } catch {
            print("Failed to save \(profile.name) sport: \(error)")
        }
    }

    // MARK: - Showcase Data for Screenshots

    func seedShowcaseDataIfNeeded(context: ModelContext) {
        guard shouldSeedShowcaseData else { return }

        seedAllSportsIfNeeded(context: context)

        guard !isShowcaseDataSeeded(context: context) else {
            return
        }

        guard let basketball = getBasketball(context: context),
              let soccer = getSoccer(context: context) else {
            print("Showcase seeding skipped: required sports are missing")
            return
        }

        let currentUser = fetchCurrentUser(context: context)
        let basketballDefinitions = definitionMap(for: basketball)
        let soccerDefinitions = definitionMap(for: soccer)

        let lions = createTeam(
            name: "Lincoln Lions",
            iconName: "basketball.fill",
            colorHex: "EA580C",
            sport: basketball,
            owner: currentUser,
            context: context
        )

        let united = createTeam(
            name: "Bay City United",
            iconName: "soccerball",
            colorHex: "16A34A",
            sport: soccer,
            owner: currentUser,
            context: context
        )

        let tigers = createTeam(
            name: "Metro Tigers",
            iconName: "figure.basketball",
            colorHex: "2563EB",
            sport: basketball,
            owner: currentUser,
            context: context
        )

        var playersByKey: [String: Person] = [:]

        playersByKey["maya"] = createPlayer(
            firstName: "Maya",
            lastName: "Chen",
            jerseyNumber: 3,
            positionAssignments: PositionAssignments(singlePosition: .pointGuard),
            owner: currentUser,
            context: context
        )
        playersByKey["jordan"] = createPlayer(
            firstName: "Jordan",
            lastName: "Alvarez",
            jerseyNumber: 11,
            positionAssignments: PositionAssignments(singlePosition: .shootingGuard),
            owner: currentUser,
            context: context
        )
        playersByKey["noah"] = createPlayer(
            firstName: "Noah",
            lastName: "Patel",
            jerseyNumber: 22,
            positionAssignments: PositionAssignments(singlePosition: .smallForward),
            owner: currentUser,
            context: context
        )
        playersByKey["leo"] = createPlayer(
            firstName: "Leo",
            lastName: "Brooks",
            jerseyNumber: 34,
            positionAssignments: PositionAssignments(singlePosition: .powerForward),
            owner: currentUser,
            context: context
        )
        playersByKey["caleb"] = createPlayer(
            firstName: "Caleb",
            lastName: "Turner",
            jerseyNumber: 50,
            positionAssignments: PositionAssignments(singlePosition: .center),
            owner: currentUser,
            context: context
        )
        playersByKey["ava"] = createPlayer(
            firstName: "Ava",
            lastName: "Kim",
            jerseyNumber: 7,
            positionAssignments: PositionAssignments(singlePosition: .shootingGuard),
            owner: currentUser,
            context: context
        )
        playersByKey["ethan"] = createPlayer(
            firstName: "Ethan",
            lastName: "Ross",
            jerseyNumber: 15,
            positionAssignments: PositionAssignments(singlePosition: .powerForward),
            owner: currentUser,
            context: context
        )

        playersByKey["sofia"] = createPlayer(
            firstName: "Sofia",
            lastName: "Martinez",
            jerseyNumber: 1,
            positionAssignments: PositionAssignments(singlePosition: .goalkeeper),
            owner: currentUser,
            context: context
        )
        playersByKey["emma"] = createPlayer(
            firstName: "Emma",
            lastName: "Fenwick",
            jerseyNumber: 4,
            positionAssignments: PositionAssignments(singlePosition: .centerBack),
            owner: currentUser,
            context: context
        )
        playersByKey["lila"] = createPlayer(
            firstName: "Lila",
            lastName: "Johnson",
            jerseyNumber: 6,
            positionAssignments: PositionAssignments(singlePosition: .defensiveMidfielder),
            owner: currentUser,
            context: context
        )
        playersByKey["harper"] = createPlayer(
            firstName: "Harper",
            lastName: "Nguyen",
            jerseyNumber: 8,
            positionAssignments: PositionAssignments(assignments: [
                PositionAssignment(position: .centralMidfielder, percentage: 65),
                PositionAssignment(position: .attackingMidfielder, percentage: 35),
            ]),
            owner: currentUser,
            context: context
        )
        playersByKey["zoe"] = createPlayer(
            firstName: "Zoe",
            lastName: "Carter",
            jerseyNumber: 10,
            positionAssignments: PositionAssignments(singlePosition: .rightWing),
            owner: currentUser,
            context: context
        )
        playersByKey["olivia"] = createPlayer(
            firstName: "Olivia",
            lastName: "Bennett",
            jerseyNumber: 9,
            positionAssignments: PositionAssignments(singlePosition: .striker),
            owner: currentUser,
            context: context
        )
        playersByKey["ruby"] = createPlayer(
            firstName: "Ruby",
            lastName: "Davis",
            jerseyNumber: 11,
            positionAssignments: PositionAssignments(singlePosition: .leftWing),
            owner: currentUser,
            context: context
        )
        playersByKey["mia"] = createPlayer(
            firstName: "Mia",
            lastName: "Thompson",
            jerseyNumber: 2,
            positionAssignments: PositionAssignments(assignments: [
                PositionAssignment(position: .rightBack, percentage: 70),
                PositionAssignment(position: .leftBack, percentage: 30),
            ]),
            owner: currentUser,
            context: context
        )

        addMembership(person: playersByKey["maya"], team: lions, jerseyNumber: 3, role: "captain", context: context)
        addMembership(person: playersByKey["jordan"], team: lions, jerseyNumber: 11, role: "player", context: context)
        addMembership(person: playersByKey["noah"], team: lions, jerseyNumber: 22, role: "player", context: context)
        addMembership(person: playersByKey["leo"], team: lions, jerseyNumber: 34, role: "player", context: context)
        addMembership(person: playersByKey["caleb"], team: lions, jerseyNumber: 50, role: "player", context: context)
        addMembership(person: playersByKey["ava"], team: lions, jerseyNumber: 7, role: "player", context: context)
        addMembership(person: playersByKey["ethan"], team: lions, jerseyNumber: 15, role: "player", context: context)

        addMembership(person: playersByKey["sofia"], team: united, jerseyNumber: 1, role: "captain", context: context)
        addMembership(person: playersByKey["emma"], team: united, jerseyNumber: 4, role: "player", context: context)
        addMembership(person: playersByKey["lila"], team: united, jerseyNumber: 6, role: "player", context: context)
        addMembership(person: playersByKey["harper"], team: united, jerseyNumber: 8, role: "player", context: context)
        addMembership(person: playersByKey["zoe"], team: united, jerseyNumber: 10, role: "player", context: context)
        addMembership(person: playersByKey["olivia"], team: united, jerseyNumber: 9, role: "player", context: context)
        addMembership(person: playersByKey["ruby"], team: united, jerseyNumber: 11, role: "player", context: context)
        addMembership(person: playersByKey["mia"], team: united, jerseyNumber: 2, role: "player", context: context)

        addMembership(person: playersByKey["maya"], team: tigers, jerseyNumber: 3, role: "player", context: context)
        addMembership(person: playersByKey["jordan"], team: tigers, jerseyNumber: 11, role: "player", context: context)
        addMembership(person: playersByKey["ethan"], team: tigers, jerseyNumber: 15, role: "player", context: context)

        let recentLionsGame = createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 0, hour: 19, minute: 5),
            opponent: "River City Raptors",
            location: "Lincoln Rec Center",
            notes: "Strong transition offense and great ball movement.",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 4, twoMissed: 3, threeMade: 2, threeMissed: 3, freeThrowMade: 3, freeThrowMissed: 1, defensiveRebounds: 3, offensiveRebounds: 1, assists: 6, steals: 2, fouls: 2),
                BasketballPlayerLine(playerKey: "jordan", twoMade: 3, twoMissed: 3, threeMade: 3, threeMissed: 4, freeThrowMade: 2, freeThrowMissed: 0, defensiveRebounds: 2, offensiveRebounds: 0, assists: 4, steals: 1, fouls: 1),
                BasketballPlayerLine(playerKey: "noah", twoMade: 5, twoMissed: 4, threeMade: 1, threeMissed: 2, freeThrowMade: 1, freeThrowMissed: 1, defensiveRebounds: 5, offensiveRebounds: 2, assists: 2, steals: 1, fouls: 3),
                BasketballPlayerLine(playerKey: "leo", twoMade: 4, twoMissed: 4, threeMade: 0, threeMissed: 1, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 6, offensiveRebounds: 3, assists: 1, steals: 1, fouls: 2),
                BasketballPlayerLine(playerKey: "ava", twoMade: 2, twoMissed: 2, threeMade: 1, threeMissed: 3, freeThrowMade: 0, freeThrowMissed: 0, defensiveRebounds: 1, offensiveRebounds: 1, assists: 3, steals: 2, fouls: 1),
            ],
            context: context
        )

        createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 1, hour: 18, minute: 40),
            opponent: "Eastview Eagles",
            location: "Eastview Middle School",
            notes: "Second-half defensive run changed the game.",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 3, twoMissed: 4, threeMade: 1, threeMissed: 3, freeThrowMade: 4, freeThrowMissed: 1, defensiveRebounds: 4, offensiveRebounds: 1, assists: 7, steals: 1, fouls: 2),
                BasketballPlayerLine(playerKey: "jordan", twoMade: 2, twoMissed: 2, threeMade: 2, threeMissed: 3, freeThrowMade: 1, freeThrowMissed: 0, defensiveRebounds: 3, offensiveRebounds: 0, assists: 2, steals: 2, fouls: 1),
                BasketballPlayerLine(playerKey: "noah", twoMade: 4, twoMissed: 3, threeMade: 1, threeMissed: 2, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 6, offensiveRebounds: 2, assists: 3, steals: 1, fouls: 2),
                BasketballPlayerLine(playerKey: "caleb", twoMade: 3, twoMissed: 2, threeMade: 0, threeMissed: 0, freeThrowMade: 2, freeThrowMissed: 2, defensiveRebounds: 7, offensiveRebounds: 4, assists: 1, steals: 0, fouls: 3),
                BasketballPlayerLine(playerKey: "ethan", twoMade: 2, twoMissed: 3, threeMade: 1, threeMissed: 1, freeThrowMade: 1, freeThrowMissed: 0, defensiveRebounds: 3, offensiveRebounds: 1, assists: 2, steals: 1, fouls: 2),
            ],
            context: context
        )

        createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 3, hour: 19, minute: 0),
            opponent: "Harbor Hawks",
            location: "Harbor Gym",
            notes: "Fast pace game with balanced scoring.",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 5, twoMissed: 3, threeMade: 1, threeMissed: 4, freeThrowMade: 2, freeThrowMissed: 0, defensiveRebounds: 3, offensiveRebounds: 1, assists: 5, steals: 3, fouls: 1),
                BasketballPlayerLine(playerKey: "jordan", twoMade: 3, twoMissed: 2, threeMade: 4, threeMissed: 3, freeThrowMade: 1, freeThrowMissed: 0, defensiveRebounds: 2, offensiveRebounds: 1, assists: 3, steals: 1, fouls: 2),
                BasketballPlayerLine(playerKey: "leo", twoMade: 4, twoMissed: 3, threeMade: 0, threeMissed: 1, freeThrowMade: 3, freeThrowMissed: 1, defensiveRebounds: 5, offensiveRebounds: 2, assists: 2, steals: 0, fouls: 2),
                BasketballPlayerLine(playerKey: "ava", twoMade: 2, twoMissed: 2, threeMade: 2, threeMissed: 2, freeThrowMade: 0, freeThrowMissed: 0, defensiveRebounds: 2, offensiveRebounds: 0, assists: 4, steals: 1, fouls: 1),
            ],
            context: context
        )

        createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 6, hour: 18, minute: 55),
            opponent: "Pinecrest Panthers",
            location: "Pinecrest HS",
            notes: "Great rebounding night from the frontcourt.",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 3, twoMissed: 4, threeMade: 2, threeMissed: 5, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 4, offensiveRebounds: 0, assists: 8, steals: 2, fouls: 2),
                BasketballPlayerLine(playerKey: "noah", twoMade: 5, twoMissed: 4, threeMade: 0, threeMissed: 2, freeThrowMade: 3, freeThrowMissed: 1, defensiveRebounds: 7, offensiveRebounds: 3, assists: 2, steals: 2, fouls: 2),
                BasketballPlayerLine(playerKey: "leo", twoMade: 4, twoMissed: 3, threeMade: 0, threeMissed: 0, freeThrowMade: 1, freeThrowMissed: 1, defensiveRebounds: 8, offensiveRebounds: 4, assists: 1, steals: 1, fouls: 3),
                BasketballPlayerLine(playerKey: "caleb", twoMade: 3, twoMissed: 2, threeMade: 0, threeMissed: 0, freeThrowMade: 2, freeThrowMissed: 2, defensiveRebounds: 6, offensiveRebounds: 3, assists: 1, steals: 0, fouls: 2),
            ],
            context: context
        )

        createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 9, hour: 19, minute: 15),
            opponent: "Valley Vipers",
            location: "Lincoln Rec Center",
            notes: "Closer finish; solid late free throw shooting.",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 4, twoMissed: 5, threeMade: 1, threeMissed: 3, freeThrowMade: 5, freeThrowMissed: 1, defensiveRebounds: 3, offensiveRebounds: 1, assists: 6, steals: 2, fouls: 3),
                BasketballPlayerLine(playerKey: "jordan", twoMade: 3, twoMissed: 4, threeMade: 2, threeMissed: 4, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 2, offensiveRebounds: 1, assists: 2, steals: 1, fouls: 2),
                BasketballPlayerLine(playerKey: "ava", twoMade: 1, twoMissed: 2, threeMade: 2, threeMissed: 2, freeThrowMade: 0, freeThrowMissed: 0, defensiveRebounds: 2, offensiveRebounds: 0, assists: 4, steals: 2, fouls: 1),
                BasketballPlayerLine(playerKey: "ethan", twoMade: 3, twoMissed: 3, threeMade: 1, threeMissed: 2, freeThrowMade: 1, freeThrowMissed: 1, defensiveRebounds: 4, offensiveRebounds: 2, assists: 1, steals: 1, fouls: 2),
            ],
            context: context
        )

        createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 13, hour: 18, minute: 30),
            opponent: "Midtown Knights",
            location: "Midtown Sports Complex",
            notes: "Big defensive effort in the second quarter.",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 3, twoMissed: 3, threeMade: 2, threeMissed: 4, freeThrowMade: 2, freeThrowMissed: 0, defensiveRebounds: 3, offensiveRebounds: 1, assists: 5, steals: 3, fouls: 1),
                BasketballPlayerLine(playerKey: "jordan", twoMade: 2, twoMissed: 2, threeMade: 3, threeMissed: 3, freeThrowMade: 1, freeThrowMissed: 0, defensiveRebounds: 1, offensiveRebounds: 0, assists: 3, steals: 2, fouls: 1),
                BasketballPlayerLine(playerKey: "noah", twoMade: 4, twoMissed: 3, threeMade: 1, threeMissed: 1, freeThrowMade: 1, freeThrowMissed: 1, defensiveRebounds: 5, offensiveRebounds: 2, assists: 2, steals: 1, fouls: 2),
                BasketballPlayerLine(playerKey: "caleb", twoMade: 3, twoMissed: 2, threeMade: 0, threeMissed: 0, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 6, offensiveRebounds: 3, assists: 1, steals: 0, fouls: 3),
            ],
            context: context
        )

        createBasketballCompletedGame(
            date: showcaseDate(daysAgo: 5, hour: 20, minute: 0),
            opponent: "Downtown Drillers",
            location: "Metro Fieldhouse",
            notes: "Metro Tigers closed out with a strong fourth quarter.",
            team: tigers,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 4, twoMissed: 3, threeMade: 2, threeMissed: 3, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 4, offensiveRebounds: 1, assists: 6, steals: 2, fouls: 2),
                BasketballPlayerLine(playerKey: "jordan", twoMade: 3, twoMissed: 3, threeMade: 2, threeMissed: 4, freeThrowMade: 1, freeThrowMissed: 0, defensiveRebounds: 2, offensiveRebounds: 1, assists: 3, steals: 1, fouls: 1),
                BasketballPlayerLine(playerKey: "ethan", twoMade: 4, twoMissed: 4, threeMade: 1, threeMissed: 2, freeThrowMade: 1, freeThrowMissed: 1, defensiveRebounds: 5, offensiveRebounds: 2, assists: 2, steals: 1, fouls: 3),
            ],
            context: context
        )

        createSoccerCompletedGame(
            date: showcaseDate(daysAgo: 2, hour: 17, minute: 45),
            opponent: "Northport FC",
            location: "Bay City Stadium",
            notes: "Great wing play and pressing in the final 20 minutes.",
            team: united,
            sport: soccer,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: soccerDefinitions,
            lines: [
                SoccerPlayerLine(playerKey: "olivia", goals: 2, shotsOnTargetMade: 3, shotsOnTargetMissed: 1, assists: 0, passes: 18, tackles: 1, interceptions: 0, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "zoe", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 2, assists: 1, passes: 22, tackles: 2, interceptions: 1, saves: 0, fouls: 0, yellowCards: 0, redCards: 0, corners: 2),
                SoccerPlayerLine(playerKey: "harper", goals: 0, shotsOnTargetMade: 1, shotsOnTargetMissed: 1, assists: 1, passes: 38, tackles: 3, interceptions: 2, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "lila", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 1, assists: 0, passes: 42, tackles: 5, interceptions: 3, saves: 0, fouls: 1, yellowCards: 1, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "sofia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 16, tackles: 0, interceptions: 0, saves: 6, fouls: 0, yellowCards: 0, redCards: 0, corners: 0),
            ],
            context: context
        )

        createSoccerCompletedGame(
            date: showcaseDate(daysAgo: 4, hour: 18, minute: 10),
            opponent: "Maplewood Strikers",
            location: "Maplewood Turf",
            notes: "Clean sheet with strong defensive shape.",
            team: united,
            sport: soccer,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: soccerDefinitions,
            lines: [
                SoccerPlayerLine(playerKey: "olivia", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 2, assists: 0, passes: 17, tackles: 1, interceptions: 0, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "ruby", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 1, assists: 1, passes: 20, tackles: 1, interceptions: 1, saves: 0, fouls: 0, yellowCards: 0, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "harper", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 1, assists: 1, passes: 40, tackles: 4, interceptions: 2, saves: 0, fouls: 0, yellowCards: 0, redCards: 0, corners: 2),
                SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 31, tackles: 6, interceptions: 4, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "sofia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 14, tackles: 0, interceptions: 0, saves: 4, fouls: 0, yellowCards: 0, redCards: 0, corners: 0),
            ],
            context: context
        )

        createSoccerCompletedGame(
            date: showcaseDate(daysAgo: 8, hour: 17, minute: 30),
            opponent: "Cedar Grove SC",
            location: "Bay City Stadium",
            notes: "Tough midfield battle and late equalizer.",
            team: united,
            sport: soccer,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: soccerDefinitions,
            lines: [
                SoccerPlayerLine(playerKey: "olivia", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 2, assists: 0, passes: 16, tackles: 1, interceptions: 0, saves: 0, fouls: 2, yellowCards: 1, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "zoe", goals: 0, shotsOnTargetMade: 1, shotsOnTargetMissed: 2, assists: 1, passes: 24, tackles: 2, interceptions: 1, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 2),
                SoccerPlayerLine(playerKey: "lila", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 44, tackles: 5, interceptions: 4, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "mia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 28, tackles: 4, interceptions: 2, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "sofia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 12, tackles: 0, interceptions: 0, saves: 5, fouls: 0, yellowCards: 0, redCards: 0, corners: 0),
            ],
            context: context
        )

        createSoccerCompletedGame(
            date: showcaseDate(daysAgo: 12, hour: 18, minute: 0),
            opponent: "Westlake Wolves",
            location: "Westlake Athletic Park",
            notes: "Strong defensive performance in windy conditions.",
            team: united,
            sport: soccer,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: soccerDefinitions,
            lines: [
                SoccerPlayerLine(playerKey: "ruby", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 1, assists: 0, passes: 21, tackles: 1, interceptions: 1, saves: 0, fouls: 0, yellowCards: 0, redCards: 0, corners: 2),
                SoccerPlayerLine(playerKey: "harper", goals: 0, shotsOnTargetMade: 1, shotsOnTargetMissed: 1, assists: 1, passes: 39, tackles: 3, interceptions: 2, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 34, tackles: 6, interceptions: 3, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "mia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 30, tackles: 4, interceptions: 2, saves: 0, fouls: 1, yellowCards: 1, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "sofia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 15, tackles: 0, interceptions: 0, saves: 3, fouls: 0, yellowCards: 0, redCards: 0, corners: 0),
            ],
            context: context
        )

        createSoccerCompletedGame(
            date: showcaseDate(daysAgo: 15, hour: 17, minute: 50),
            opponent: "Riverside Rovers",
            location: "Bay City Stadium",
            notes: "Early pressure led to two first-half goals.",
            team: united,
            sport: soccer,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: soccerDefinitions,
            lines: [
                SoccerPlayerLine(playerKey: "olivia", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 1, assists: 1, passes: 19, tackles: 1, interceptions: 0, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 1),
                SoccerPlayerLine(playerKey: "zoe", goals: 1, shotsOnTargetMade: 2, shotsOnTargetMissed: 1, assists: 0, passes: 23, tackles: 2, interceptions: 1, saves: 0, fouls: 0, yellowCards: 0, redCards: 0, corners: 2),
                SoccerPlayerLine(playerKey: "lila", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 43, tackles: 5, interceptions: 3, saves: 0, fouls: 1, yellowCards: 1, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 33, tackles: 5, interceptions: 3, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                SoccerPlayerLine(playerKey: "sofia", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 13, tackles: 0, interceptions: 0, saves: 4, fouls: 0, yellowCards: 0, redCards: 0, corners: 0),
            ],
            context: context
        )

        createActiveBasketballGame(
            date: showcaseDate(daysAgo: 0, hour: 21, minute: 15),
            opponent: "Westfield Wildcats",
            location: "Lincoln Rec Center",
            notes: "In progress - third quarter",
            team: lions,
            sport: basketball,
            trackedBy: currentUser,
            playersByKey: playersByKey,
            definitionsByShortName: basketballDefinitions,
            lines: [
                BasketballPlayerLine(playerKey: "maya", twoMade: 2, twoMissed: 1, threeMade: 1, threeMissed: 2, freeThrowMade: 1, freeThrowMissed: 0, defensiveRebounds: 2, offensiveRebounds: 0, assists: 3, steals: 1, fouls: 1),
                BasketballPlayerLine(playerKey: "noah", twoMade: 2, twoMissed: 2, threeMade: 0, threeMissed: 1, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 3, offensiveRebounds: 1, assists: 1, steals: 1, fouls: 2),
            ],
            context: context
        )

        if let maya = playersByKey["maya"],
           let mayaStats = recentLionsGame.personStats?.first(where: { $0.person?.id == maya.id }) {
            addCompletedShifts(
                to: mayaStats,
                gameDate: recentLionsGame.gameDate,
                seeds: [
                    ShiftSeed(startTeamScore: 0, startOpponentScore: 0, endTeamScore: 12, endOpponentScore: 8, durationMinutes: 7),
                    ShiftSeed(startTeamScore: 12, startOpponentScore: 8, endTeamScore: 23, endOpponentScore: 16, durationMinutes: 8),
                ],
                context: context
            )
        }

        if let jordan = playersByKey["jordan"],
           let jordanStats = recentLionsGame.personStats?.first(where: { $0.person?.id == jordan.id }) {
            addCompletedShifts(
                to: jordanStats,
                gameDate: recentLionsGame.gameDate,
                seeds: [
                    ShiftSeed(startTeamScore: 0, startOpponentScore: 0, endTeamScore: 8, endOpponentScore: 9, durationMinutes: 6),
                    ShiftSeed(startTeamScore: 8, startOpponentScore: 9, endTeamScore: 18, endOpponentScore: 15, durationMinutes: 7),
                ],
                context: context
            )
        }

        if let currentUser,
           currentUser.currentStreak == 0 {
            currentUser.currentStreak = 6
            currentUser.longestStreak = 9
            currentUser.lastGameDate = showcaseDate(daysAgo: 0, hour: 19, minute: 5)
        }

        do {
            try context.save()
            print("Showcase data seeded successfully")
        } catch {
            print("Failed to save showcase data: \(error)")
        }
    }

    // Backward-compatible entry point used by older call sites.
    func seedJackJamesIfNeeded(context: ModelContext) {
        guard shouldSeedFenwickData else { return }
        seedAllSportsIfNeeded(context: context)
        removeShowcaseDataIfPresent(context: context)
        seedFenwickPlayersIfNeeded(context: context)
    }

    // MARK: - Sports Helpers

    private func fetchSport(named name: String, context: ModelContext) -> Sport? {
        do {
            let sports = try context.fetch(FetchDescriptor<Sport>())
            return sports.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        } catch {
            print("Failed to fetch sports: \(error)")
            return nil
        }
    }

    private func ensureStatDefinitions(for sport: Sport, from seeds: [StatSeed], context: ModelContext) {
        let existing = sport.statDefinitions ?? []
        var byShortName: [String: StatDefinition] = [:]
        for definition in existing {
            byShortName[definition.shortName] = definition
        }

        for seed in seeds {
            if let definition = byShortName[seed.shortName] {
                definition.name = seed.name
                definition.category = seed.category
                definition.hasMadeAndMissed = seed.hasMadeAndMissed
                definition.pointValue = seed.pointValue
                definition.sortOrder = seed.sortOrder
                definition.iconName = seed.iconName
                definition.sport = sport
                appendUnique(definition, to: &sport.statDefinitions)
            } else {
                let definition = StatDefinition(
                    name: seed.name,
                    shortName: seed.shortName,
                    category: seed.category,
                    hasMadeAndMissed: seed.hasMadeAndMissed,
                    pointValue: seed.pointValue,
                    sortOrder: seed.sortOrder,
                    iconName: seed.iconName,
                    sport: sport
                )
                context.insert(definition)
                appendUnique(definition, to: &sport.statDefinitions)
            }
        }
    }

    private func definitionMap(for sport: Sport) -> [String: StatDefinition] {
        var map: [String: StatDefinition] = [:]
        for definition in sport.statDefinitions ?? [] {
            map[definition.shortName] = definition
        }
        return map
    }

    // MARK: - Showcase Construction

    private func isShowcaseDataSeeded(context: ModelContext) -> Bool {
        do {
            let teams = try context.fetch(FetchDescriptor<Team>())
            return teams.contains { $0.name == showcaseMarkerTeamName }
        } catch {
            print("Failed to check showcase marker: \(error)")
            return false
        }
    }

    private func fetchCurrentUser(context: ModelContext) -> User? {
        do {
            let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\User.createdAt)])
            let users = try context.fetch(descriptor)
            if let currentUserID = AppState.shared.currentUserID,
               let matched = users.first(where: { $0.id == currentUserID }) {
                return matched
            }

            let fallback = users.first
            if let fallback, AppState.shared.currentUserID == nil {
                AppState.shared.currentUserID = fallback.id
            }
            return fallback
        } catch {
            print("Failed to fetch users: \(error)")
            return nil
        }
    }

    private func seedFenwickPlayersIfNeeded(context: ModelContext) {
        do {
            let people = try context.fetch(FetchDescriptor<Person>())
            let currentUser = fetchCurrentUser(context: context)
            guard let basketball = getBasketball(context: context),
                  let soccer = getSoccer(context: context) else {
                return
            }

            let jackAssignments = PositionAssignments(singlePosition: .center)
            let emmaAssignments = PositionAssignments(singlePosition: .defender)

            let jack = people.first(where: { matches($0, firstName: "Jack", lastName: "Fenwick") }) ??
                createPlayer(
                    firstName: "Jack",
                    lastName: "Fenwick",
                    jerseyNumber: 50,
                    positionAssignments: jackAssignments,
                    owner: currentUser,
                    context: context
                )

            let emma = people.first(where: { matches($0, firstName: "Emma", lastName: "Fenwick") }) ??
                createPlayer(
                    firstName: "Emma",
                    lastName: "Fenwick",
                    jerseyNumber: 4,
                    positionAssignments: emmaAssignments,
                    owner: currentUser,
                    context: context
                )

            jack.jerseyNumber = 50
            jack.positionAssignments = jackAssignments
            jack.position = jackAssignments.displayText
            jack.isActive = true
            if jack.owner == nil {
                jack.owner = currentUser
                if let currentUser {
                    appendUnique(jack, to: &currentUser.people)
                }
            }

            emma.jerseyNumber = 4
            emma.positionAssignments = emmaAssignments
            emma.position = emmaAssignments.displayText
            emma.isActive = true
            if emma.owner == nil {
                emma.owner = currentUser
                if let currentUser {
                    appendUnique(emma, to: &currentUser.people)
                }
            }

            let venom = fetchTeam(named: "Venom", sportName: "Basketball", context: context) ??
                createTeam(
                    name: "Venom",
                    iconName: "basketball.fill",
                    colorHex: "DC2626",
                    sport: basketball,
                    owner: currentUser,
                    context: context
                )
            venom.iconName = "basketball.fill"
            venom.colorHex = "DC2626"
            venom.sport = basketball
            venom.isActive = true
            if venom.owner == nil { venom.owner = currentUser }
            appendUnique(venom, to: &basketball.teams)
            if let currentUser {
                appendUnique(venom, to: &currentUser.teams)
            }

            let comets = fetchTeam(named: "Comets", sportName: "Soccer", context: context) ??
                createTeam(
                    name: "Comets",
                    iconName: "soccerball",
                    colorHex: "2563EB",
                    sport: soccer,
                    owner: currentUser,
                    context: context
                )
            comets.iconName = "soccerball"
            comets.colorHex = "2563EB"
            comets.sport = soccer
            comets.isActive = true
            if comets.owner == nil { comets.owner = currentUser }
            appendUnique(comets, to: &soccer.teams)
            if let currentUser {
                appendUnique(comets, to: &currentUser.teams)
            }

            ensureMembership(
                person: jack,
                team: venom,
                jerseyNumber: 50,
                role: "player",
                positionAssignments: jackAssignments,
                context: context
            )

            ensureMembership(
                person: emma,
                team: comets,
                jerseyNumber: 4,
                role: "player",
                positionAssignments: emmaAssignments,
                context: context
            )

            let basketballDefinitions = definitionMap(for: basketball)
            let soccerDefinitions = definitionMap(for: soccer)

            let jackSeededCount = fenwickHistoryGameCount(
                team: venom,
                player: jack,
                playerMarker: "Jack",
                context: context
            )
            if jackSeededCount < fenwickHistoryGamesPerPlayer {
                let jackDaysAgo = [1, 3, 5, 8, 11, 14, 18]
                let jackOpponents = [
                    "Harbor Hawks",
                    "Maple Ridge Warriors",
                    "Eastview Eagles",
                    "Pinecrest Panthers",
                    "Valley Vipers",
                    "Midtown Knights",
                    "Cedar City Cyclones",
                ]
                let jackLines = [
                    BasketballPlayerLine(playerKey: "jack", twoMade: 6, twoMissed: 4, threeMade: 0, threeMissed: 1, freeThrowMade: 3, freeThrowMissed: 2, defensiveRebounds: 9, offensiveRebounds: 4, assists: 2, steals: 1, fouls: 3),
                    BasketballPlayerLine(playerKey: "jack", twoMade: 5, twoMissed: 5, threeMade: 0, threeMissed: 0, freeThrowMade: 4, freeThrowMissed: 1, defensiveRebounds: 11, offensiveRebounds: 3, assists: 1, steals: 1, fouls: 2),
                    BasketballPlayerLine(playerKey: "jack", twoMade: 7, twoMissed: 3, threeMade: 0, threeMissed: 1, freeThrowMade: 2, freeThrowMissed: 2, defensiveRebounds: 10, offensiveRebounds: 5, assists: 3, steals: 2, fouls: 2),
                    BasketballPlayerLine(playerKey: "jack", twoMade: 4, twoMissed: 4, threeMade: 0, threeMissed: 0, freeThrowMade: 5, freeThrowMissed: 2, defensiveRebounds: 8, offensiveRebounds: 2, assists: 2, steals: 1, fouls: 4),
                    BasketballPlayerLine(playerKey: "jack", twoMade: 6, twoMissed: 5, threeMade: 0, threeMissed: 0, freeThrowMade: 3, freeThrowMissed: 3, defensiveRebounds: 12, offensiveRebounds: 4, assists: 2, steals: 0, fouls: 3),
                    BasketballPlayerLine(playerKey: "jack", twoMade: 5, twoMissed: 3, threeMade: 0, threeMissed: 0, freeThrowMade: 2, freeThrowMissed: 1, defensiveRebounds: 10, offensiveRebounds: 3, assists: 2, steals: 1, fouls: 2),
                    BasketballPlayerLine(playerKey: "jack", twoMade: 8, twoMissed: 4, threeMade: 0, threeMissed: 0, freeThrowMade: 4, freeThrowMissed: 2, defensiveRebounds: 13, offensiveRebounds: 5, assists: 1, steals: 1, fouls: 3),
                ]

                for index in jackSeededCount..<fenwickHistoryGamesPerPlayer {
                    createBasketballCompletedGame(
                        date: showcaseDate(daysAgo: jackDaysAgo[index], hour: 19, minute: 10),
                        opponent: jackOpponents[index],
                        location: "Venom Home Court",
                        notes: "\(fenwickHistoryTag)[Jack][Game \(index + 1)] Realistic center stat line for historical trend seeding.",
                        team: venom,
                        sport: basketball,
                        trackedBy: currentUser,
                        playersByKey: ["jack": jack],
                        definitionsByShortName: basketballDefinitions,
                        lines: [jackLines[index]],
                        context: context
                    )
                }
            }

            let emmaSeededCount = fenwickHistoryGameCount(
                team: comets,
                player: emma,
                playerMarker: "Emma",
                context: context
            )
            if emmaSeededCount < fenwickHistoryGamesPerPlayer {
                let emmaDaysAgo = [2, 4, 6, 9, 12, 16, 20]
                let emmaOpponents = [
                    "Northport FC",
                    "Riverside Rovers",
                    "Westlake Wolves",
                    "Cedar Grove SC",
                    "Maplewood Strikers",
                    "Lakeside United",
                    "Hillcrest Athletic",
                ]
                let emmaLines = [
                    SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 34, tackles: 7, interceptions: 4, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                    SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 31, tackles: 6, interceptions: 5, saves: 0, fouls: 1, yellowCards: 1, redCards: 0, corners: 0),
                    SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 1, passes: 37, tackles: 8, interceptions: 3, saves: 0, fouls: 0, yellowCards: 0, redCards: 0, corners: 1),
                    SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 33, tackles: 5, interceptions: 4, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                    SoccerPlayerLine(playerKey: "emma", goals: 1, shotsOnTargetMade: 1, shotsOnTargetMissed: 0, assists: 0, passes: 35, tackles: 6, interceptions: 4, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                    SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 0, assists: 0, passes: 32, tackles: 7, interceptions: 5, saves: 0, fouls: 2, yellowCards: 1, redCards: 0, corners: 0),
                    SoccerPlayerLine(playerKey: "emma", goals: 0, shotsOnTargetMade: 0, shotsOnTargetMissed: 1, assists: 0, passes: 36, tackles: 6, interceptions: 4, saves: 0, fouls: 1, yellowCards: 0, redCards: 0, corners: 0),
                ]

                for index in emmaSeededCount..<fenwickHistoryGamesPerPlayer {
                    createSoccerCompletedGame(
                        date: showcaseDate(daysAgo: emmaDaysAgo[index], hour: 18, minute: 20),
                        opponent: emmaOpponents[index],
                        location: "Comets Stadium",
                        notes: "\(fenwickHistoryTag)[Emma][Game \(index + 1)] Realistic defender stat line for historical trend seeding.",
                        team: comets,
                        sport: soccer,
                        trackedBy: currentUser,
                        playersByKey: ["emma": emma],
                        definitionsByShortName: soccerDefinitions,
                        lines: [emmaLines[index]],
                        context: context
                    )
                }
            }

            try context.save()
        } catch {
            print("Failed to seed Fenwick players: \(error)")
        }
    }

    private func removeShowcaseDataIfPresent(context: ModelContext) {
        do {
            let teams = try context.fetch(FetchDescriptor<Team>())
            let showcaseTeams = teams.filter { showcaseTeamNames.contains($0.name) }
            let availableShowcaseNames = Set(showcaseTeams.map(\.name))
            guard showcaseTeamNames.isSubset(of: availableShowcaseNames) else { return }

            let showcaseTeamIDs = Set(showcaseTeams.map(\.id))
            let games = try context.fetch(FetchDescriptor<Game>())
            let showcaseGames = games.filter { game in
                guard let teamID = game.team?.id else { return false }
                return showcaseTeamIDs.contains(teamID)
            }
            guard showcaseGames.contains(where: { showcaseKnownOpponents.contains($0.opponent) }) else { return }

            var showcasePersonIDs: Set<UUID> = []
            for team in showcaseTeams {
                for membership in team.memberships ?? [] {
                    if let personID = membership.person?.id {
                        showcasePersonIDs.insert(personID)
                    }
                }
            }
            for game in showcaseGames {
                for personStats in game.personStats ?? [] {
                    if let personID = personStats.person?.id {
                        showcasePersonIDs.insert(personID)
                    }
                }
            }

            for game in showcaseGames {
                context.delete(game)
            }

            for team in showcaseTeams {
                context.delete(team)
            }

            let people = try context.fetch(FetchDescriptor<Person>())
            for person in people where showcasePersonIDs.contains(person.id) {
                context.delete(person)
            }

            try context.save()
            print("Showcase data removed")
        } catch {
            print("Failed to remove showcase data: \(error)")
        }
    }

    private func matches(_ person: Person, firstName: String, lastName: String) -> Bool {
        person.firstName.caseInsensitiveCompare(firstName) == .orderedSame &&
            person.lastName.caseInsensitiveCompare(lastName) == .orderedSame
    }

    private func fetchTeam(named name: String, sportName: String, context: ModelContext) -> Team? {
        do {
            let teams = try context.fetch(FetchDescriptor<Team>())
            return teams.first { team in
                team.name.caseInsensitiveCompare(name) == .orderedSame &&
                team.sport?.name.caseInsensitiveCompare(sportName) == .orderedSame
            }
        } catch {
            print("Failed to fetch teams: \(error)")
            return nil
        }
    }

    private func ensureMembership(
        person: Person,
        team: Team,
        jerseyNumber: Int,
        role: String,
        positionAssignments: PositionAssignments,
        context: ModelContext
    ) {
        if let existingMembership = (person.teamMemberships ?? []).first(where: { $0.team?.id == team.id }) {
            existingMembership.jerseyNumber = jerseyNumber
            existingMembership.role = role
            existingMembership.positionAssignments = positionAssignments
            existingMembership.position = positionAssignments.displayText
            existingMembership.isActive = true
            appendUnique(existingMembership, to: &team.memberships)
            appendUnique(existingMembership, to: &person.teamMemberships)
            return
        }

        let membership = TeamMembership(
            person: person,
            team: team,
            role: role,
            jerseyNumber: jerseyNumber,
            position: positionAssignments.displayText,
            positionAssignments: positionAssignments,
            isActive: true
        )
        context.insert(membership)
        appendUnique(membership, to: &team.memberships)
        appendUnique(membership, to: &person.teamMemberships)
    }

    private func fenwickHistoryGameCount(
        team: Team,
        player: Person,
        playerMarker: String,
        context: ModelContext
    ) -> Int {
        do {
            let games = try context.fetch(FetchDescriptor<Game>())
            return games.filter { game in
                guard game.team?.id == team.id else { return false }
                guard game.notes.contains("\(fenwickHistoryTag)[\(playerMarker)]") else { return false }
                return (game.personStats ?? []).contains(where: { $0.person?.id == player.id })
            }.count
        } catch {
            print("Failed to count Fenwick history games: \(error)")
            return 0
        }
    }

    private func createTeam(
        name: String,
        iconName: String,
        colorHex: String,
        sport: Sport,
        owner: User?,
        context: ModelContext
    ) -> Team {
        let team = Team(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            isActive: true,
            sport: sport,
            owner: owner
        )
        context.insert(team)

        appendUnique(team, to: &sport.teams)
        if let owner {
            appendUnique(team, to: &owner.teams)
        }

        return team
    }

    private func createPlayer(
        firstName: String,
        lastName: String,
        jerseyNumber: Int,
        positionAssignments: PositionAssignments,
        owner: User?,
        context: ModelContext
    ) -> Person {
        let player = Person(
            firstName: firstName,
            lastName: lastName,
            jerseyNumber: jerseyNumber,
            position: positionAssignments.displayText,
            positionAssignments: positionAssignments,
            isActive: true,
            owner: owner
        )
        context.insert(player)

        if let owner {
            appendUnique(player, to: &owner.people)
        }

        return player
    }

    private func addMembership(
        person: Person?,
        team: Team,
        jerseyNumber: Int,
        role: String,
        context: ModelContext
    ) {
        guard let person else { return }

        let assignments = person.positionAssignments
        let membership = TeamMembership(
            person: person,
            team: team,
            role: role,
            jerseyNumber: jerseyNumber,
            position: assignments.displayText,
            positionAssignments: assignments,
            isActive: true
        )
        context.insert(membership)

        appendUnique(membership, to: &team.memberships)
        appendUnique(membership, to: &person.teamMemberships)
    }

    @discardableResult
    private func createBasketballCompletedGame(
        date: Date,
        opponent: String,
        location: String,
        notes: String,
        team: Team,
        sport: Sport,
        trackedBy: User?,
        playersByKey: [String: Person],
        definitionsByShortName: [String: StatDefinition],
        lines: [BasketballPlayerLine],
        context: ModelContext
    ) -> Game {
        let game = Game(
            gameDate: date,
            opponent: opponent,
            location: location,
            notes: notes,
            isCompleted: true,
            sport: sport,
            trackedBy: trackedBy
        )
        game.team = team
        context.insert(game)

        appendUnique(game, to: &team.games)
        appendUnique(game, to: &sport.games)
        if let trackedBy {
            appendUnique(game, to: &trackedBy.trackedGames)
        }

        var aggregates: [String: AggregateCounts] = [:]

        for line in lines {
            guard let player = playersByKey[line.playerKey] else { continue }
            let personStats = PersonGameStats(person: player, game: game)
            context.insert(personStats)

            appendUnique(personStats, to: &player.gameStats)
            appendUnique(personStats, to: &game.personStats)

            addBasketballLine(
                line,
                to: personStats,
                definitionsByShortName: definitionsByShortName,
                context: context,
                aggregates: &aggregates
            )
        }

        createAggregateGameStats(
            for: game,
            definitionsByShortName: definitionsByShortName,
            aggregates: aggregates,
            context: context
        )

        return game
    }

    private func createSoccerCompletedGame(
        date: Date,
        opponent: String,
        location: String,
        notes: String,
        team: Team,
        sport: Sport,
        trackedBy: User?,
        playersByKey: [String: Person],
        definitionsByShortName: [String: StatDefinition],
        lines: [SoccerPlayerLine],
        context: ModelContext
    ) {
        let game = Game(
            gameDate: date,
            opponent: opponent,
            location: location,
            notes: notes,
            isCompleted: true,
            sport: sport,
            trackedBy: trackedBy
        )
        game.team = team
        context.insert(game)

        appendUnique(game, to: &team.games)
        appendUnique(game, to: &sport.games)
        if let trackedBy {
            appendUnique(game, to: &trackedBy.trackedGames)
        }

        var aggregates: [String: AggregateCounts] = [:]

        for line in lines {
            guard let player = playersByKey[line.playerKey] else { continue }
            let personStats = PersonGameStats(person: player, game: game)
            context.insert(personStats)

            appendUnique(personStats, to: &player.gameStats)
            appendUnique(personStats, to: &game.personStats)

            addSoccerLine(
                line,
                to: personStats,
                definitionsByShortName: definitionsByShortName,
                context: context,
                aggregates: &aggregates
            )
        }

        createAggregateGameStats(
            for: game,
            definitionsByShortName: definitionsByShortName,
            aggregates: aggregates,
            context: context
        )
    }

    private func createActiveBasketballGame(
        date: Date,
        opponent: String,
        location: String,
        notes: String,
        team: Team,
        sport: Sport,
        trackedBy: User?,
        playersByKey: [String: Person],
        definitionsByShortName: [String: StatDefinition],
        lines: [BasketballPlayerLine],
        context: ModelContext
    ) {
        let game = Game(
            gameDate: date,
            opponent: opponent,
            location: location,
            notes: notes,
            isCompleted: false,
            sport: sport,
            trackedBy: trackedBy
        )
        game.team = team
        context.insert(game)

        appendUnique(game, to: &team.games)
        appendUnique(game, to: &sport.games)
        if let trackedBy {
            appendUnique(game, to: &trackedBy.trackedGames)
        }

        var aggregates: [String: AggregateCounts] = [:]
        var mayaStats: PersonGameStats?

        for line in lines {
            guard let player = playersByKey[line.playerKey] else { continue }
            let personStats = PersonGameStats(person: player, game: game)
            context.insert(personStats)

            appendUnique(personStats, to: &player.gameStats)
            appendUnique(personStats, to: &game.personStats)

            addBasketballLine(
                line,
                to: personStats,
                definitionsByShortName: definitionsByShortName,
                context: context,
                aggregates: &aggregates
            )

            if line.playerKey == "maya" {
                mayaStats = personStats
            }
        }

        createAggregateGameStats(
            for: game,
            definitionsByShortName: definitionsByShortName,
            aggregates: aggregates,
            context: context
        )

        if let mayaStats {
            let activeShift = Shift(shiftNumber: 1, personGameStats: mayaStats, teamScore: 10, opponentScore: 8)
            activeShift.startTime = Date().addingTimeInterval(-8 * 60)
            context.insert(activeShift)
            appendUnique(activeShift, to: &mayaStats.shifts)
        }
    }

    private func addBasketballLine(
        _ line: BasketballPlayerLine,
        to personStats: PersonGameStats,
        definitionsByShortName: [String: StatDefinition],
        context: ModelContext,
        aggregates: inout [String: AggregateCounts]
    ) {
        recordPersonStat(
            shortName: "2PT",
            made: line.twoMade,
            missed: line.twoMissed,
            count: 0,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "3PT",
            made: line.threeMade,
            missed: line.threeMissed,
            count: 0,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "FT",
            made: line.freeThrowMade,
            missed: line.freeThrowMissed,
            count: 0,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "DREB",
            made: 0,
            missed: 0,
            count: line.defensiveRebounds,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "OREB",
            made: 0,
            missed: 0,
            count: line.offensiveRebounds,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "AST",
            made: 0,
            missed: 0,
            count: line.assists,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "STL",
            made: 0,
            missed: 0,
            count: line.steals,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "PF",
            made: 0,
            missed: 0,
            count: line.fouls,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
    }

    private func addSoccerLine(
        _ line: SoccerPlayerLine,
        to personStats: PersonGameStats,
        definitionsByShortName: [String: StatDefinition],
        context: ModelContext,
        aggregates: inout [String: AggregateCounts]
    ) {
        recordPersonStat(
            shortName: "GOL",
            made: line.goals,
            missed: 0,
            count: 0,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "SOT",
            made: line.shotsOnTargetMade,
            missed: line.shotsOnTargetMissed,
            count: 0,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "AST",
            made: 0,
            missed: 0,
            count: line.assists,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "PAS",
            made: 0,
            missed: 0,
            count: line.passes,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "TKL",
            made: 0,
            missed: 0,
            count: line.tackles,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "INT",
            made: 0,
            missed: 0,
            count: line.interceptions,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "SAV",
            made: 0,
            missed: 0,
            count: line.saves,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "FLS",
            made: 0,
            missed: 0,
            count: line.fouls,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "YC",
            made: 0,
            missed: 0,
            count: line.yellowCards,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "RC",
            made: 0,
            missed: 0,
            count: line.redCards,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
        recordPersonStat(
            shortName: "CRN",
            made: 0,
            missed: 0,
            count: line.corners,
            personStats: personStats,
            definitionsByShortName: definitionsByShortName,
            context: context,
            aggregates: &aggregates
        )
    }

    private func recordPersonStat(
        shortName: String,
        made: Int,
        missed: Int,
        count: Int,
        personStats: PersonGameStats,
        definitionsByShortName: [String: StatDefinition],
        context: ModelContext,
        aggregates: inout [String: AggregateCounts]
    ) {
        guard made > 0 || missed > 0 || count > 0 else { return }

        let definition = definitionsByShortName[shortName]
        let pointValue = definition?.pointValue ?? 0

        let stat = Stat(
            statName: shortName,
            pointValue: pointValue,
            made: made,
            missed: missed,
            count: count,
            definition: definition,
            personGameStats: personStats
        )
        context.insert(stat)
        appendUnique(stat, to: &personStats.stats)

        if var aggregate = aggregates[shortName] {
            aggregate.made += made
            aggregate.missed += missed
            aggregate.count += count
            aggregates[shortName] = aggregate
        } else {
            aggregates[shortName] = AggregateCounts(
                pointValue: pointValue,
                made: made,
                missed: missed,
                count: count
            )
        }
    }

    private func createAggregateGameStats(
        for game: Game,
        definitionsByShortName: [String: StatDefinition],
        aggregates: [String: AggregateCounts],
        context: ModelContext
    ) {
        let keys = aggregates.keys.sorted { left, right in
            (definitionsByShortName[left]?.sortOrder ?? 999) < (definitionsByShortName[right]?.sortOrder ?? 999)
        }

        for key in keys {
            guard let aggregate = aggregates[key] else { continue }

            let stat = Stat(
                statName: key,
                pointValue: aggregate.pointValue,
                made: aggregate.made,
                missed: aggregate.missed,
                count: aggregate.count,
                definition: definitionsByShortName[key],
                personGameStats: nil
            )
            stat.game = game
            context.insert(stat)
            appendUnique(stat, to: &game.stats)
        }
    }

    private func addCompletedShifts(
        to personStats: PersonGameStats,
        gameDate: Date,
        seeds: [ShiftSeed],
        context: ModelContext
    ) {
        var currentStart = gameDate.addingTimeInterval(5 * 60)

        for (index, seed) in seeds.enumerated() {
            let shift = Shift(
                shiftNumber: index + 1,
                personGameStats: personStats,
                teamScore: seed.startTeamScore,
                opponentScore: seed.startOpponentScore
            )

            shift.startTime = currentStart
            shift.endTime = currentStart.addingTimeInterval(TimeInterval(seed.durationMinutes * 60))
            shift.endingTeamScore = seed.endTeamScore
            shift.endingOpponentScore = seed.endOpponentScore

            context.insert(shift)
            appendUnique(shift, to: &personStats.shifts)

            currentStart = (shift.endTime ?? currentStart).addingTimeInterval(90)
        }
    }

    private func showcaseDate(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? Date()
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day) ?? day
    }

    private func appendUnique<T: AnyObject>(_ element: T, to array: inout [T]?) {
        if array == nil {
            array = []
        }

        let exists = array?.contains(where: { $0 === element }) ?? false
        if !exists {
            array?.append(element)
        }
    }
}
