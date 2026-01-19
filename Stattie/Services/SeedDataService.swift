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
            ("Foul", "PF", "other", false, 0, 6, "exclamationmark.triangle.fill"),
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
}
