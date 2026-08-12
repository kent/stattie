import Foundation
import SwiftData

enum StatMutation: Equatable {
    case made
    case missed
    case count
}

@Model
final class Stat {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var made: Int = 0
    var missed: Int = 0
    var count: Int = 0

    // Store stat info directly so we don't need StatDefinition
    var statName: String = ""  // "2PT", "3PT", "FT", "DREB", "OREB", "STL", "PF", "TO"
    var pointValue: Int = 0    // Points per made shot (2, 3, 1, or 0)

    var definition: StatDefinition?
    var personGameStats: PersonGameStats?
    var game: Game?
    var shift: Shift?

    var total: Int {
        made + missed + count
    }

    var isEmpty: Bool {
        made == 0 && missed == 0 && count == 0
    }

    var percentage: Double? {
        let attempts = made + missed
        guard attempts > 0 else { return nil }
        return Double(made) / Double(attempts)
    }

    var formattedPercentage: String? {
        guard let pct = percentage else { return nil }
        return String(format: "%.0f%%", pct * 100)
    }

    var points: Int {
        pointValue * made
    }

    var displayValue: String {
        if pointValue > 0 {
            return "\(made)/\(made + missed)"
        }
        return "\(count)"
    }

    init(
        statName: String = "",
        pointValue: Int = 0,
        made: Int = 0,
        missed: Int = 0,
        count: Int = 0,
        definition: StatDefinition? = nil,
        personGameStats: PersonGameStats? = nil,
        game: Game? = nil,
        shift: Shift? = nil
    ) {
        self.id = UUID()
        self.statName = statName
        self.pointValue = pointValue
        self.made = made
        self.missed = missed
        self.count = count
        self.definition = definition
        self.personGameStats = personGameStats
        self.game = game
        self.shift = shift
        self.timestamp = Date()
    }

    /// Applies a stat change. Negative deltas are clamped at zero, making undo safe.
    @discardableResult
    func apply(_ mutation: StatMutation, delta: Int = 1, at date: Date = Date()) -> Bool {
        guard delta != 0 else { return false }

        switch mutation {
        case .made:
            guard made + delta >= 0 else { return false }
            made += delta
        case .missed:
            guard missed + delta >= 0 else { return false }
            missed += delta
        case .count:
            guard count + delta >= 0 else { return false }
            count += delta
        }

        timestamp = date
        return true
    }
}


// MARK: - Legacy ShiftStat migration

struct StatAttributionMigrationReport: Equatable {
    var migratedLegacyStats: Int = 0
    var alreadyMigratedLegacyStats: Int = 0
    var linkedExistingStatsToGames: Int = 0
    var reconciledMirroredValues: Int = 0
    var removedMirroredGameStats: Int = 0
    var preservedAmbiguousGameAggregates: Int = 0
    var skippedOrphanedStats: Int = 0
}

enum StatAttributionMigration {
    private struct AggregateKey: Hashable {
        let gameID: UUID
        let statName: String
    }

    private struct Totals {
        var made = 0
        var missed = 0
        var count = 0
    }

    /// Converts legacy ShiftStat rows to canonical, fully attributed Stat rows.
    ///
    /// The legacy tracker wrote the same tap to an unattributed game aggregate and
    /// a ShiftStat. For newly converted rows this migration consumes only the
    /// mirrored portion of the unattributed aggregate, leaving any non-shift events
    /// intact. Conversion, reconciliation, legacy cleanup, and save are one
    /// transaction. A rerun is therefore a no-op.
    @MainActor
    static func migrateLegacyShiftStats(
        in context: ModelContext,
        save: (() throws -> Void)? = nil
    ) throws -> StatAttributionMigrationReport {
        var report = StatAttributionMigrationReport()

        do {
            let existingStats = try context.fetch(FetchDescriptor<Stat>())
            let legacyStats = try context.fetch(FetchDescriptor<ShiftStat>())
            var statsByID: [UUID: Stat] = [:]
            for stat in existingStats where statsByID[stat.id] == nil {
                statsByID[stat.id] = stat
            }

            // Stat was historically allowed to be person-only. Repair that older
            // shape before all readers begin requiring the canonical game link.
            for stat in existingStats where stat.game == nil {
                guard let game = stat.personGameStats?.game else { continue }
                stat.game = game
                appendUnique(stat, to: &game.stats)
                report.linkedExistingStatsToGames += 1
            }

            // Snapshot legacy game aggregates before inserting attributed records.
            let directAggregateRows = existingStats.filter {
                $0.game != nil && $0.personGameStats == nil && $0.shift == nil
            }
            var migratedTotals: [AggregateKey: Totals] = [:]
            var handledLegacyIDs = Set<UUID>()

            for legacy in legacyStats {
                guard handledLegacyIDs.insert(legacy.id).inserted else {
                    context.delete(legacy)
                    continue
                }
                guard let shift = legacy.shift,
                      let personGameStats = shift.personGameStats,
                      let game = personGameStats.game else {
                    report.skippedOrphanedStats += 1
                    continue
                }

                if let existing = statsByID[legacy.id] {
                    // Deterministic IDs identify a row converted by an earlier
                    // migration implementation. Never steal a coincidentally
                    // conflicting record from another owner.
                    guard (existing.game == nil || existing.game?.id == game.id),
                          (existing.personGameStats == nil || existing.personGameStats?.id == personGameStats.id),
                          (existing.shift == nil || existing.shift?.id == shift.id) else {
                        report.skippedOrphanedStats += 1
                        continue
                    }
                    if existing.game == nil { existing.game = game }
                    if existing.personGameStats == nil { existing.personGameStats = personGameStats }
                    if existing.shift == nil { existing.shift = shift }
                    appendUnique(existing, to: &game.stats)
                    appendUnique(existing, to: &personGameStats.stats)
                    appendUnique(existing, to: &shift.statRecords)
                    context.delete(legacy)
                    report.alreadyMigratedLegacyStats += 1
                    continue
                }

                let canonical = Stat(
                    statName: legacy.statName,
                    pointValue: legacy.pointValue,
                    made: legacy.made,
                    missed: legacy.missed,
                    count: legacy.count,
                    definition: legacy.definition,
                    personGameStats: personGameStats,
                    game: game,
                    shift: shift
                )
                canonical.id = legacy.id
                canonical.timestamp = legacy.timestamp
                context.insert(canonical)
                appendUnique(canonical, to: &game.stats)
                appendUnique(canonical, to: &personGameStats.stats)
                appendUnique(canonical, to: &shift.statRecords)
                statsByID[canonical.id] = canonical

                let key = AggregateKey(gameID: game.id, statName: legacy.statName)
                var totals = migratedTotals[key, default: Totals()]
                totals.made += legacy.made
                totals.missed += legacy.missed
                totals.count += legacy.count
                migratedTotals[key] = totals

                context.delete(legacy)
                report.migratedLegacyStats += 1
            }

            for (key, totals) in migratedTotals {
                let matchingRows = directAggregateRows.filter {
                    $0.game?.id == key.gameID && $0.statName == key.statName
                }
                let directTotals = matchingRows.reduce(into: Totals()) { result, row in
                    result.made += row.made
                    result.missed += row.missed
                    result.count += row.count
                }

                // Only discard the legacy game aggregate when it is an exact
                // component-for-component mirror. A partial overlap is ambiguous:
                // older versions also supported game-only and shift-only writers,
                // so subtracting a partial match could destroy valid events.
                guard !matchingRows.isEmpty,
                      directTotals.made == totals.made,
                      directTotals.missed == totals.missed,
                      directTotals.count == totals.count else {
                    if !matchingRows.isEmpty {
                        report.preservedAmbiguousGameAggregates += 1
                    }
                    continue
                }

                for aggregate in matchingRows {
                    report.reconciledMirroredValues += aggregate.made + aggregate.missed + aggregate.count
                    if let game = aggregate.game {
                        game.stats?.removeAll { $0.id == aggregate.id }
                    }
                    context.delete(aggregate)
                    report.removedMirroredGameStats += 1
                }
            }

            if context.hasChanges {
                if let save {
                    try save()
                } else {
                    try context.save()
                }
            }
            return report
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func appendUnique(_ value: Stat, to array: inout [Stat]?) {
        if array == nil { array = [] }
        if array?.contains(where: { $0.id == value.id }) == false {
            array?.append(value)
        }
    }
}
