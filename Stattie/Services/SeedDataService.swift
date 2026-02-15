import Foundation
import SwiftData

final class SeedDataService {
    static let shared = SeedDataService()

    private init() {}

    func seedBasketballIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Sport>(predicate: #Predicate { $0.name == "Basketball" })

        do {
            let existingSports = try context.fetch(descriptor)
            if existingSports.isEmpty {
                createBasketballSport(context: context)
            }
        } catch {
            print("Failed to check for existing sports: \(error)")
            createBasketballSport(context: context)
        }
    }

    private func createBasketballSport(context: ModelContext) {
        let basketball = Sport(name: "Basketball", iconName: "basketball.fill", isBuiltIn: true)
        context.insert(basketball)

        let statDefinitions: [(String, String, String, Bool, Int, Int, String)] = [
            ("2-Point Shot", "2PT", "shooting", true, 2, 0, "basketball.fill"),
            ("3-Point Shot", "3PT", "shooting", true, 3, 1, "basketball.fill"),
            ("Free Throw", "FT", "shooting", true, 1, 2, "basketball.fill"),
            ("Defensive Rebound", "DREB", "rebounding", false, 0, 3, "arrow.down.circle.fill"),
            ("Offensive Rebound", "OREB", "rebounding", false, 0, 4, "arrow.up.circle.fill"),
            ("Steal", "STL", "defense", false, 0, 5, "hand.raised.fill"),
            ("Assist", "AST", "offense", false, 0, 6, "arrow.triangle.branch"),
            ("Foul", "PF", "other", false, 0, 7, "exclamationmark.triangle.fill"),
            ("Drive", "DRV", "offense", false, 0, 8, "figure.run"),
            ("Great Play", "GP", "other", false, 0, 9, "star.fill"),
        ]

        for (index, def) in statDefinitions.enumerated() {
            let statDef = StatDefinition(
                name: def.0,
                shortName: def.1,
                category: def.2,
                hasMadeAndMissed: def.3,
                pointValue: def.4,
                sortOrder: def.5,
                iconName: def.6,
                sport: basketball
            )
            context.insert(statDef)

            if basketball.statDefinitions == nil {
                basketball.statDefinitions = []
            }
            basketball.statDefinitions?.append(statDef)
        }

        do {
            try context.save()
            print("Basketball sport seeded successfully")
        } catch {
            print("Failed to save basketball sport: \(error)")
        }
    }

    func getBasketball(context: ModelContext) -> Sport? {
        let descriptor = FetchDescriptor<Sport>(predicate: #Predicate { $0.name == "Basketball" })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Soccer Seeding

    func seedSoccerIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Sport>(predicate: #Predicate { $0.name == "Soccer" })

        do {
            let existingSports = try context.fetch(descriptor)
            if existingSports.isEmpty {
                createSoccerSport(context: context)
            }
        } catch {
            print("Failed to check for existing soccer sport: \(error)")
            createSoccerSport(context: context)
        }
    }

    private func createSoccerSport(context: ModelContext) {
        let soccer = Sport(name: "Soccer", iconName: "soccerball", isBuiltIn: true)
        context.insert(soccer)

        let statDefinitions: [(String, String, String, Bool, Int, Int, String)] = [
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

        for def in statDefinitions {
            let statDef = StatDefinition(
                name: def.0,
                shortName: def.1,
                category: def.2,
                hasMadeAndMissed: def.3,
                pointValue: def.4,
                sortOrder: def.5,
                iconName: def.6,
                sport: soccer
            )
            context.insert(statDef)

            if soccer.statDefinitions == nil {
                soccer.statDefinitions = []
            }
            soccer.statDefinitions?.append(statDef)
        }

        do {
            try context.save()
            print("Soccer sport seeded successfully")
        } catch {
            print("Failed to save soccer sport: \(error)")
        }
    }

    func getSoccer(context: ModelContext) -> Sport? {
        let descriptor = FetchDescriptor<Sport>(predicate: #Predicate { $0.name == "Soccer" })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Seed All Sports

    func seedAllSportsIfNeeded(context: ModelContext) {
        seedBasketballIfNeeded(context: context)
        seedSoccerIfNeeded(context: context)
    }

    // MARK: - Test Data

    func seedJackJamesIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.firstName == "Jack" && $0.lastName == "James" })

        do {
            let existingPeople = try context.fetch(descriptor)
            if existingPeople.isEmpty {
                createJackJamesWithHistory(context: context)
            }
        } catch {
            print("Failed to check for Jack James: \(error)")
        }
    }

    private func createJackJamesWithHistory(context: ModelContext) {
        // Create Jack James
        let jack = Person(
            firstName: "Jack",
            lastName: "James",
            jerseyNumber: 23,
            position: "Point Guard"
        )
        context.insert(jack)

        // Get basketball sport
        let basketball = getBasketball(context: context)

        // NBA team names for opponents
        let opponents = [
            "Lakers", "Celtics", "Warriors", "Heat", "Nets",
            "Bulls", "Knicks", "Suns", "Bucks", "76ers",
            "Mavericks", "Clippers", "Nuggets", "Grizzlies", "Cavaliers"
        ]

        // Create 45 games over the past 6 months
        let calendar = Calendar.current
        let today = Date()

        for gameIndex in 0..<45 {
            // Game date: spread over past 180 days
            let daysAgo = 180 - (gameIndex * 4) // roughly every 4 days
            guard let gameDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            let opponent = opponents[gameIndex % opponents.count]
            let game = Game(
                gameDate: gameDate,
                opponent: opponent,
                isCompleted: true,
                sport: basketball
            )
            context.insert(game)

            // Create PersonGameStats for Jack in this game
            let personStats = PersonGameStats(person: jack, game: game)
            context.insert(personStats)

            // Link relationships
            if jack.gameStats == nil { jack.gameStats = [] }
            jack.gameStats?.append(personStats)

            if game.personStats == nil { game.personStats = [] }
            game.personStats?.append(personStats)

            // Generate realistic stats with some variance and trends
            // Jack improves slightly over time (lower gameIndex = older games)
            let improvementFactor = 1.0 + (Double(gameIndex) / 100.0) // 0% to 45% improvement

            // Base stats with randomness
            let twoPointMade = Int(Double.random(in: 3...8) * improvementFactor)
            let twoPointMissed = Int.random(in: 2...6)
            let threePointMade = Int(Double.random(in: 1...4) * improvementFactor)
            let threePointMissed = Int.random(in: 2...5)
            let ftMade = Int.random(in: 2...6)
            let ftMissed = Int.random(in: 0...2)

            let defensiveRebounds = Int(Double.random(in: 2...6) * improvementFactor)
            let offensiveRebounds = Int.random(in: 0...3)
            let steals = Int(Double.random(in: 1...4) * improvementFactor)
            let assists = Int(Double.random(in: 3...8) * improvementFactor)
            let fouls = Int.random(in: 1...4)
            let drives = Int.random(in: 2...6)
            let greatPlays = Int.random(in: 0...3)

            // Create stat objects
            let stats: [(String, Int, Int, Int, Int)] = [
                // (statName, pointValue, made, missed, count)
                ("2PT", 2, twoPointMade, twoPointMissed, 0),
                ("3PT", 3, threePointMade, threePointMissed, 0),
                ("FT", 1, ftMade, ftMissed, 0),
                ("DREB", 0, 0, 0, defensiveRebounds),
                ("OREB", 0, 0, 0, offensiveRebounds),
                ("STL", 0, 0, 0, steals),
                ("AST", 0, 0, 0, assists),
                ("PF", 0, 0, 0, fouls),
                ("DRV", 0, 0, 0, drives),
                ("GP", 0, 0, 0, greatPlays),
            ]

            for (statName, pointValue, made, missed, count) in stats {
                let stat = Stat(
                    statName: statName,
                    pointValue: pointValue,
                    made: made,
                    missed: missed,
                    count: count,
                    personGameStats: personStats
                )
                context.insert(stat)

                if personStats.stats == nil { personStats.stats = [] }
                personStats.stats?.append(stat)
            }
        }

        do {
            try context.save()
            print("Jack James seeded with 45 games of history")
        } catch {
            print("Failed to save Jack James: \(error)")
        }
    }
}
