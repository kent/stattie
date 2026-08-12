import Foundation
import SwiftUI
import SwiftData

final class ShareService {
    static let shared = ShareService()

    private init() {}

    func generateTextSummary(for game: Game) -> String {
        var lines: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        lines.append("GAME SUMMARY")
        lines.append(String(repeating: "=", count: 40))

        if !game.opponent.isEmpty {
            lines.append("vs \(game.opponent)")
        }

        lines.append(dateFormatter.string(from: game.gameDate))

        if !game.location.isEmpty {
            lines.append("Location: \(game.location)")
        }

        lines.append("")
        lines.append("FINAL SCORE: \(game.totalPoints) points")
        lines.append(String(repeating: "-", count: 40))

        let personStats = (game.personStats ?? []).sorted {
            ($0.person?.jerseyNumber ?? 0) < ($1.person?.jerseyNumber ?? 0)
        }

        for pgs in personStats {
            guard let person = pgs.person else { continue }
            let stats = pgs.stats ?? []
            if stats.isEmpty || stats.allSatisfy({ $0.total == 0 }) { continue }

            lines.append("")
            lines.append("\(person.displayName)")
            lines.append("  Points: \(pgs.totalPoints)")

            let shootingStats = stats.filter { $0.definition?.hasMadeAndMissed == true && $0.total > 0 }
            for stat in shootingStats.sorted(by: { ($0.definition?.sortOrder ?? 0) < ($1.definition?.sortOrder ?? 0) }) {
                if let def = stat.definition {
                    let pctString = stat.formattedPercentage.map { " (\($0))" } ?? ""
                    lines.append("  \(def.shortName): \(stat.made)/\(stat.made + stat.missed)\(pctString)")
                }
            }

            let countStats = stats.filter { $0.definition?.hasMadeAndMissed == false && $0.count > 0 }
            for stat in countStats.sorted(by: { ($0.definition?.sortOrder ?? 0) < ($1.definition?.sortOrder ?? 0) }) {
                if let def = stat.definition {
                    lines.append("  \(def.shortName): \(stat.count)")
                }
            }
        }

        if !game.notes.isEmpty {
            lines.append("")
            lines.append("Notes: \(game.notes)")
        }

        lines.append("")
        lines.append("Tracked with Stattie")

        return lines.joined(separator: "\n")
    }

    @MainActor
    func share(game: Game, from view: UIView? = nil) {
        let text = generateTextSummary(for: game)
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view ?? rootVC.view
                popover.sourceRect = view?.bounds ?? CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct CoachingResourceLink: Identifiable, Hashable, Codable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }

    init(title: String, urlString: String) {
        self.title = title
        self.url = URL(string: urlString) ?? URL(string: "https://www.youtube.com")!
    }
}

struct CoachingFocusItem: Identifiable, Hashable, Codable {
    let rank: Int
    let title: String
    let whyItMatters: String
    let actionPlan: String
    let resources: [CoachingResourceLink]
    let confirmationCount: Int

    var id: String { "\(rank)|\(title)" }

    init(
        rank: Int,
        title: String,
        whyItMatters: String,
        actionPlan: String,
        resources: [CoachingResourceLink],
        confirmationCount: Int = 1
    ) {
        self.rank = rank
        self.title = title
        self.whyItMatters = whyItMatters
        self.actionPlan = actionPlan
        self.resources = resources
        self.confirmationCount = confirmationCount
    }
}

struct CoachingInsightReport: Hashable, Codable {
    enum Source: String, Hashable, Codable {
        case onDevice = "On Device"
    }

    let source: Source
    let generatedAt: Date
    let headline: String
    let summary: String
    let focusItems: [CoachingFocusItem]
}

/// Produces coaching recommendations entirely on-device from recorded stats.
/// This service never sends player, game, or team data over the network.
final class LocalCoachingService {
    static let shared = LocalCoachingService()

    private struct StoredAcademyTodoEntry: Codable {
        var topicKey: String
        var title: String
        var whyItMatters: String
        var actionPlan: String
        var resources: [CoachingResourceLink]
        var confirmationCount: Int
        var firstSeenAt: Date
        var lastUpdatedAt: Date
        var sourceGameIDs: [UUID]
    }

    private struct StoredAcademyTodoSnapshot: Codable {
        var updatedAt: Date
        var entries: [StoredAcademyTodoEntry]
    }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let academySampleGameLimit = 14
    private var hasBootstrappedCloudCache = false

    private init() {
        // Remove obsolete remote-coaching configuration from earlier builds.
        UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
        UserDefaults.standard.removeObject(forKey: "aiCoachEndpointURL")
        UserDefaults.standard.removeObject(forKey: "aiCoachProxyToken")
    }

    func bootstrapCloudCacheIfNeeded(force: Bool = false) {
        if hasBootstrappedCloudCache && !force { return }
        hasBootstrappedCloudCache = true
        migrateLegacyDefaultsCacheToCloudStore()
    }

    var academyStatsWindow: Int {
        academySampleGameLimit
    }

    @MainActor
    func refreshPostGameInsightsInBackground(for game: Game) {
        Task(priority: .background) { @MainActor in
            _ = await generateAndCacheEndOfGameInsights(for: game, forceRefresh: true)

            for player in uniquePlayers(in: game) {
                let report = await generateAndCacheAcademyPlan(
                    for: player,
                    sourceGameID: game.id,
                    forceRefresh: true
                )

                let topFocusTitle = report.focusItems
                    .sorted(by: { $0.rank < $1.rank })
                    .first?.title

                NotificationManager.shared.sendAcademyPlanReadyNotification(
                    playerName: player.displayName,
                    playerID: player.id,
                    gameID: game.id,
                    topFocusTitle: topFocusTitle
                )
            }
        }
    }

    @MainActor
    func cachedEndOfGameInsights(for game: Game) -> CoachingInsightReport? {
        bootstrapCloudCacheIfNeeded()
        return loadReport(forKey: gameReportKey(for: game))
    }

    @MainActor
    func cachedAcademyPlan(for player: Person) -> CoachingInsightReport? {
        bootstrapCloudCacheIfNeeded()
        return loadReport(forKey: playerPlanKey(for: player))
    }

    @MainActor
    func academyTodoFocusItems(for player: Person, limit: Int = 3) -> [CoachingFocusItem] {
        bootstrapCloudCacheIfNeeded()
        let ranked = rankedTodoEntries(for: player)
        guard !ranked.isEmpty else { return [] }

        return Array(ranked.prefix(limit)).enumerated().map { index, entry in
            CoachingFocusItem(
                rank: index + 1,
                title: entry.title,
                whyItMatters: entry.whyItMatters,
                actionPlan: entry.actionPlan,
                resources: entry.resources,
                confirmationCount: entry.confirmationCount
            )
        }
    }

    @MainActor
    func generateAndCacheEndOfGameInsights(
        for game: Game,
        forceRefresh: Bool = false
    ) async -> CoachingInsightReport {
        if !forceRefresh, let cached = cachedEndOfGameInsights(for: game) {
            return cached
        }

        let report = await generateEndOfGameInsights(for: game)
        saveReport(report, forKey: gameReportKey(for: game))
        return report
    }

    @MainActor
    func generateAndCacheAcademyPlan(
        for player: Person,
        sourceGameID: UUID? = nil,
        forceRefresh: Bool = false
    ) async -> CoachingInsightReport {
        if !forceRefresh, let cached = cachedAcademyPlan(for: player) {
            _ = mergeAcademyTodos(for: player, focusItems: cached.focusItems, sourceGameID: sourceGameID)
            return cached
        }

        let report = localAcademyPlan(for: player)
        saveReport(report, forKey: playerPlanKey(for: player))
        _ = mergeAcademyTodos(for: player, focusItems: report.focusItems, sourceGameID: sourceGameID)
        return report
    }

    func generateEndOfGameInsights(for game: Game) async -> CoachingInsightReport {
        localGameInsights(for: game)
    }

    func generateAcademyPlan(for player: Person) async -> CoachingInsightReport {
        localAcademyPlan(for: player)
    }

    // MARK: - Local Storage + Todo Grouping

    private func gameReportKey(for game: Game) -> String {
        "local.coaching.game.\(ownershipScope(for: game)).\(game.id.uuidString)"
    }

    private func playerPlanKey(for player: Person) -> String {
        "local.coaching.player.plan.\(ownershipScope(for: player)).\(player.id.uuidString)"
    }

    private func playerTodoKey(for player: Person) -> String {
        "local.coaching.player.todo.\(ownershipScope(for: player)).\(player.id.uuidString)"
    }

    private func ownershipScope(for game: Game) -> String {
        if let trackedBy = game.trackedBy?.id {
            return trackedBy.uuidString
        }
        if let teamOwner = game.team?.owner?.id {
            return teamOwner.uuidString
        }
        if let playerOwner = (game.personStats ?? []).compactMap({ $0.person?.owner?.id }).first {
            return playerOwner.uuidString
        }
        if let currentUserID = AppState.shared.currentUserID {
            return currentUserID.uuidString
        }
        return "global"
    }

    private func ownershipScope(for player: Person) -> String {
        if let owner = player.owner?.id {
            return owner.uuidString
        }
        if let currentUserID = AppState.shared.currentUserID {
            return currentUserID.uuidString
        }
        return "global"
    }

    private func loadReport(forKey key: String) -> CoachingInsightReport? {
        if let data = loadCloudCacheData(forKey: key) {
            do {
                return try decoder.decode(CoachingInsightReport.self, from: data)
            } catch {
                removeCloudCacheData(forKey: key)
            }
        }

        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let report = try decoder.decode(CoachingInsightReport.self, from: data)
            saveCloudCacheData(data, forKey: key)
            return report
        } catch {
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    private func saveReport(_ report: CoachingInsightReport, forKey key: String) {
        do {
            let data = try encoder.encode(report)
            defaults.set(data, forKey: key)
            saveCloudCacheData(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
            removeCloudCacheData(forKey: key)
        }
    }

    private func uniquePlayers(in game: Game) -> [Person] {
        var seen = Set<UUID>()
        var players: [Person] = []
        for person in (game.personStats ?? []).compactMap(\.person) {
            if seen.insert(person.id).inserted {
                players.append(person)
            }
        }
        return players
    }

    private func loadTodoSnapshot(for player: Person) -> StoredAcademyTodoSnapshot {
        let key = playerTodoKey(for: player)
        if let cloudData = loadCloudCacheData(forKey: key) {
            do {
                return try decoder.decode(StoredAcademyTodoSnapshot.self, from: cloudData)
            } catch {
                removeCloudCacheData(forKey: key)
            }
        }

        guard let localData = defaults.data(forKey: key) else {
            return StoredAcademyTodoSnapshot(updatedAt: Date(), entries: [])
        }
        do {
            let snapshot = try decoder.decode(StoredAcademyTodoSnapshot.self, from: localData)
            saveCloudCacheData(localData, forKey: key)
            return snapshot
        } catch {
            defaults.removeObject(forKey: key)
            removeCloudCacheData(forKey: key)
            return StoredAcademyTodoSnapshot(updatedAt: Date(), entries: [])
        }
    }

    private func saveTodoSnapshot(_ snapshot: StoredAcademyTodoSnapshot, for player: Person) {
        let key = playerTodoKey(for: player)
        do {
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: key)
            saveCloudCacheData(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
            removeCloudCacheData(forKey: key)
        }
    }

    private func loadCloudCacheData(forKey key: String) -> Data? {
        guard let context = SharedModelContainer.makeContext() else { return nil }
        let lookupKey = key
        let descriptor = FetchDescriptor<SyncedAICacheEntry>(
            predicate: #Predicate { entry in
                entry.cacheKey == lookupKey
            }
        )

        do {
            return try context.fetch(descriptor).first?.payload
        } catch {
            return nil
        }
    }

    private func saveCloudCacheData(_ payload: Data, forKey key: String) {
        guard let context = SharedModelContainer.makeContext() else { return }
        let lookupKey = key
        let descriptor = FetchDescriptor<SyncedAICacheEntry>(
            predicate: #Predicate { entry in
                entry.cacheKey == lookupKey
            }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.payload = payload
                existing.updatedAt = Date()
            } else {
                let entry = SyncedAICacheEntry(cacheKey: key, payload: payload)
                context.insert(entry)
            }
            try context.save()
        } catch {
            // Keep local defaults as fallback.
        }
    }

    private func removeCloudCacheData(forKey key: String) {
        guard let context = SharedModelContainer.makeContext() else { return }
        let lookupKey = key
        let descriptor = FetchDescriptor<SyncedAICacheEntry>(
            predicate: #Predicate { entry in
                entry.cacheKey == lookupKey
            }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                context.delete(existing)
                try context.save()
            }
        } catch {
            // Ignore cleanup errors.
        }
    }

    private func migrateLegacyDefaultsCacheToCloudStore() {
        guard let context = SharedModelContainer.makeContext() else { return }

        let legacyEntries = defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("local.coaching.") }

        guard !legacyEntries.isEmpty else { return }

        for (key, value) in legacyEntries {
            guard let payload = value as? Data else { continue }

            let lookupKey = key
            let descriptor = FetchDescriptor<SyncedAICacheEntry>(
                predicate: #Predicate { entry in
                    entry.cacheKey == lookupKey
                }
            )

            do {
                if let existing = try context.fetch(descriptor).first {
                    if existing.payload.isEmpty {
                        existing.payload = payload
                        existing.updatedAt = Date()
                    }
                } else {
                    context.insert(SyncedAICacheEntry(cacheKey: key, payload: payload))
                }
            } catch {
                continue
            }
        }

        do {
            try context.save()
        } catch {
            // Best-effort migration only.
        }
    }

    private func rankedTodoEntries(for player: Person) -> [StoredAcademyTodoEntry] {
        let snapshot = loadTodoSnapshot(for: player)
        return snapshot.entries.sorted { left, right in
            let leftScore = todoPriorityScore(for: left)
            let rightScore = todoPriorityScore(for: right)
            if leftScore == rightScore {
                return left.lastUpdatedAt > right.lastUpdatedAt
            }
            return leftScore > rightScore
        }
    }

    @MainActor
    private func mergeAcademyTodos(
        for player: Person,
        focusItems: [CoachingFocusItem],
        sourceGameID: UUID?
    ) -> [CoachingFocusItem] {
        guard !focusItems.isEmpty else { return academyTodoFocusItems(for: player) }

        var snapshot = loadTodoSnapshot(for: player)
        var byTopic = Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.topicKey, $0) })
        let now = Date()

        var seenTopics = Set<String>()
        for item in focusItems.sorted(by: { $0.rank < $1.rank }) {
            let topic = todoTopicKey(for: item)
            guard seenTopics.insert(topic).inserted else { continue }

            if var existing = byTopic[topic] {
                existing.title = item.title
                existing.whyItMatters = item.whyItMatters
                existing.actionPlan = item.actionPlan
                existing.resources = mergedResources(existing.resources, item.resources)
                existing.lastUpdatedAt = now
                existing.confirmationCount += 1
                if let sourceGameID, !existing.sourceGameIDs.contains(sourceGameID) {
                    existing.sourceGameIDs.append(sourceGameID)
                }
                byTopic[topic] = existing
            } else {
                byTopic[topic] = StoredAcademyTodoEntry(
                    topicKey: topic,
                    title: item.title,
                    whyItMatters: item.whyItMatters,
                    actionPlan: item.actionPlan,
                    resources: item.resources,
                    confirmationCount: max(1, item.confirmationCount),
                    firstSeenAt: now,
                    lastUpdatedAt: now,
                    sourceGameIDs: sourceGameID.map { [$0] } ?? []
                )
            }
        }

        snapshot.updatedAt = now
        snapshot.entries = Array(byTopic.values)
        saveTodoSnapshot(snapshot, for: player)
        return academyTodoFocusItems(for: player)
    }

    private func mergedResources(
        _ existing: [CoachingResourceLink],
        _ incoming: [CoachingResourceLink]
    ) -> [CoachingResourceLink] {
        var links: [CoachingResourceLink] = []
        var seen = Set<String>()

        for link in existing + incoming {
            let key = link.url.absoluteString
            if seen.insert(key).inserted {
                links.append(link)
            }
        }
        return Array(links.prefix(3))
    }

    private func todoPriorityScore(for entry: StoredAcademyTodoEntry) -> Double {
        let recencyHours = Date().timeIntervalSince(entry.lastUpdatedAt) / 3600
        let recencyBoost = max(0, 48 - recencyHours) * 0.5
        return (Double(entry.confirmationCount) * 100) + recencyBoost
    }

    private func todoTopicKey(for item: CoachingFocusItem) -> String {
        let text = "\(item.title) \(item.actionPlan)".lowercased()

        if text.contains("turnover") || text.contains("ball security") || text.contains("dribble") || text.contains("handle") {
            return "ball-security"
        }
        if text.contains("shoot") || text.contains("shot") || text.contains("free throw") || text.contains("finish") {
            return "shooting-finishing"
        }
        if text.contains("rebound") || text.contains("box out") || text.contains("glass") {
            return "rebounding"
        }
        if text.contains("assist") || text.contains("pass") || text.contains("playmaking") {
            return "passing-playmaking"
        }
        if text.contains("defend") || text.contains("steal") || text.contains("interception") || text.contains("tackle") {
            return "defense"
        }
        if text.contains("foul") || text.contains("discipline") || text.contains("card") {
            return "discipline"
        }
        if text.contains("condition") || text.contains("fitness") || text.contains("stamina") {
            return "conditioning"
        }

        let normalized = item.title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: "-")
        return normalized.isEmpty ? "general-development" : normalized
    }

    func localAcademyPlan(for player: Person) -> CoachingInsightReport {
        let sport = inferredSport(for: player)
        let position = resolvedPrimaryPosition(for: player, sport: sport)
        let recentStats = recentCompletedGameStats(for: player, limit: academySampleGameLimit)
        let metrics = buildPlayerMetrics(from: recentStats, sport: sport)

        var candidates = localCandidates(for: metrics, sport: sport, position: position)
        if candidates.count < 3 {
            candidates.append(contentsOf: defaultCandidates(for: sport))
        }

        let top = Array(candidates.sorted {
            if $0.priority == $1.priority { return $0.title < $1.title }
            return $0.priority > $1.priority
        }.prefix(3))
        let focusItems = top.enumerated().map { index, candidate in
            CoachingFocusItem(
                rank: index + 1,
                title: candidate.title,
                whyItMatters: candidate.why,
                actionPlan: candidate.action,
                resources: resources(for: candidate.tags, sport: sport)
            )
        }

        let positionText = position?.displayName ?? (sport == .basketball ? "Basketball Player" : "Soccer Player")
        return CoachingInsightReport(
            source: .onDevice,
            generatedAt: recentStats.compactMap { $0.game?.gameDate }.max() ?? player.createdAt,
            headline: "Priority plan for \(positionText)",
            summary: "Ranked from your recent game trends and current production.",
            focusItems: focusItems
        )
    }

    func localGameInsights(for game: Game) -> CoachingInsightReport {
        let sport = inferredSport(for: game)
        var candidates = localGameCandidates(for: game, sport: sport)
        if candidates.count < 3 {
            candidates.append(contentsOf: defaultCandidates(for: sport))
        }

        let top = Array(candidates.sorted {
            if $0.priority == $1.priority { return $0.title < $1.title }
            return $0.priority > $1.priority
        }.prefix(3))
        let focusItems = top.enumerated().map { index, candidate in
            CoachingFocusItem(
                rank: index + 1,
                title: candidate.title,
                whyItMatters: candidate.why,
                actionPlan: candidate.action,
                resources: resources(for: candidate.tags, sport: sport)
            )
        }

        return CoachingInsightReport(
            source: .onDevice,
            generatedAt: game.gameDate,
            headline: "Three priorities before the next game",
            summary: "Built privately on this device from the stats recorded in this game.",
            focusItems: focusItems
        )
    }

    // MARK: - Local Analysis

    private enum ResourceTag: String {
        case shooting
        case freeThrows
        case ballHandling
        case decisionMaking
        case rebounding
        case perimeterDefense
        case finishing
        case passing
        case firstTouch
        case tackling
        case goalkeeping
        case conditioning
    }

    private struct FocusCandidate {
        let title: String
        let why: String
        let action: String
        let priority: Int
        let tags: [ResourceTag]
    }

    private struct PlayerMetrics {
        let primaryProductionPerGame: Double
        let primaryEfficiency: Double
        let secondaryEfficiency: Double
        let tertiaryEfficiency: Double
        let reboundsPerGame: Double
        let assistsPerGame: Double
        let turnoversPerGame: Double
        let stealsPerGame: Double
        let passesPerGame: Double
        let defensiveActionsPerGame: Double
        let foulsPerGame: Double
        let cardsPerGame: Double
        let savesPerGame: Double

        var riskPerGame: Double {
            turnoversPerGame + foulsPerGame + cardsPerGame
        }
    }

    private func localGameCandidates(for game: Game, sport: SoccerPosition.SupportedSport) -> [FocusCandidate] {
        if sport == .basketball {
            let twoMade = game.totalMade(forName: "2PT")
            let threeMade = game.totalMade(forName: "3PT")
            let ftMade = game.totalMade(forName: "FT")
            let twoAtt = twoMade + game.totalMissed(forName: "2PT")
            let threeAtt = threeMade + game.totalMissed(forName: "3PT")
            let ftAtt = ftMade + game.totalMissed(forName: "FT")
            let fgAtt = twoAtt + threeAtt
            let fgPct = fgAtt > 0 ? Double(twoMade + threeMade) / Double(fgAtt) : 0
            let ftPct = ftAtt > 0 ? Double(ftMade) / Double(ftAtt) : 0
            let assists = game.totalCount(forName: "AST")
            let turnovers = game.totalCount(forName: "TO")
            let rebounds = game.totalCount(forName: "DREB") + game.totalCount(forName: "OREB")
            let fouls = game.totalCount(forName: "PF")

            return [
                FocusCandidate(
                    title: "Raise shot quality and conversion",
                    why: "Field goal efficiency is below target, which limits scoring consistency.",
                    action: "Run 15 minutes of game-speed finishing and catch-and-shoot drills before scrimmage.",
                    priority: max(10, Int((0.50 - fgPct) * 120)),
                    tags: [.shooting, .finishing]
                ),
                FocusCandidate(
                    title: "Protect possessions under pressure",
                    why: "Turnovers are high relative to assists and can swing momentum.",
                    action: "Add pressure ball-handling and decision-making reps with 12-second constraints.",
                    priority: max(8, (turnovers - assists + 3) * 8),
                    tags: [.ballHandling, .decisionMaking]
                ),
                FocusCandidate(
                    title: "Win the glass every quarter",
                    why: "Rebounding volume is low for a complete game profile.",
                    action: "Add box-out and second-jump rebounding drills for 10 minutes each session.",
                    priority: max(6, 40 - rebounds),
                    tags: [.rebounding, .conditioning]
                ),
                FocusCandidate(
                    title: "Improve free-throw reliability",
                    why: "Free-throw percentage is leaving points available.",
                    action: "Finish each practice with 3 pressure sets of 10 free throws and track makes.",
                    priority: ftAtt >= 4 ? max(5, Int((0.75 - ftPct) * 100)) : 4,
                    tags: [.freeThrows, .shooting]
                ),
                FocusCandidate(
                    title: "Defend without fouling",
                    why: "Foul count is elevated and can reduce lineup flexibility.",
                    action: "Use closeout and lateral containment drills emphasizing chest-up contests.",
                    priority: fouls * 6,
                    tags: [.perimeterDefense, .conditioning]
                ),
            ]
        } else {
            let goals = game.totalCount(forName: "GOL")
            let shotsMade = game.totalMade(forName: "SOT")
            let shotsAtt = shotsMade + game.totalMissed(forName: "SOT")
            let shotAccuracy = shotsAtt > 0 ? Double(shotsMade) / Double(shotsAtt) : 0
            let passes = game.totalCount(forName: "PAS")
            let tackles = game.totalCount(forName: "TKL")
            let interceptions = game.totalCount(forName: "INT")
            let fouls = game.totalCount(forName: "FLS")
            let cards = game.totalCount(forName: "YC") + game.totalCount(forName: "RC")

            return [
                FocusCandidate(
                    title: "Convert chances at a higher rate",
                    why: "Shot efficiency can improve, especially in decisive moments.",
                    action: "Run first-touch finishing circuits and one-touch shooting from multiple angles.",
                    priority: max(10, Int((0.50 - shotAccuracy) * 120)),
                    tags: [.finishing, .firstTouch]
                ),
                FocusCandidate(
                    title: "Increase passing tempo and quality",
                    why: "Passing volume is low for sustained possession control.",
                    action: "Add 3 rondo blocks (4v2 / 5v2) each practice with two-touch limits.",
                    priority: max(7, 120 - passes),
                    tags: [.passing, .decisionMaking]
                ),
                FocusCandidate(
                    title: "Strengthen defensive duels",
                    why: "Defensive actions are low relative to game demands.",
                    action: "Train tackle timing and interception anticipation in transition games.",
                    priority: max(6, 30 - (tackles + interceptions)),
                    tags: [.tackling, .conditioning]
                ),
                FocusCandidate(
                    title: "Stay disciplined defensively",
                    why: "Fouls and cards can quickly put pressure on the team shape.",
                    action: "Use controlled defending drills focused on body angle and timing.",
                    priority: (fouls * 4) + (cards * 6),
                    tags: [.tackling, .decisionMaking]
                ),
                FocusCandidate(
                    title: "Turn shots into goals",
                    why: "Finishing output is below chance creation volume.",
                    action: "Practice 20 high-repetition finishing attempts from central and wide channels.",
                    priority: max(5, (shotsAtt - goals) * 4),
                    tags: [.finishing, .shooting]
                ),
            ]
        }
    }

    private func localCandidates(
        for metrics: PlayerMetrics,
        sport: SoccerPosition.SupportedSport,
        position: SoccerPosition?
    ) -> [FocusCandidate] {
        if sport == .basketball {
            let isGuard = position == .pointGuard || position == .shootingGuard
            let isBig = position == .powerForward || position == .center

            return [
                FocusCandidate(
                    title: "Raise scoring efficiency",
                    why: "Current field goal efficiency suggests too many empty possessions.",
                    action: "Prioritize shot selection reps: paint finishes, rhythm pull-ups, and catch-and-shoot work.",
                    priority: max(8, Int((0.50 - metrics.primaryEfficiency) * 120)),
                    tags: [.shooting, .finishing]
                ),
                FocusCandidate(
                    title: "Improve free-throw consistency",
                    why: "Free throws are a controllable scoring area that can increase output quickly.",
                    action: "Complete 30 tracked free throws after every workout with make targets.",
                    priority: max(5, Int((0.78 - metrics.tertiaryEfficiency) * 90)),
                    tags: [.freeThrows, .shooting]
                ),
                FocusCandidate(
                    title: "Tighten ball security",
                    why: "Turnovers are limiting possessions and decision quality.",
                    action: "Run pressure dribbling, weak-hand handling, and read-react passing drills.",
                    priority: max(6, Int((metrics.turnoversPerGame - 1.8) * 14)),
                    tags: [.ballHandling, .decisionMaking]
                ),
                FocusCandidate(
                    title: "Create easier offense for teammates",
                    why: "More quality assists can improve team efficiency and spacing.",
                    action: "Practice drive-and-kick reads and PnR passing windows at game speed.",
                    priority: isGuard ? max(5, Int((4.0 - metrics.assistsPerGame) * 10)) : max(3, Int((2.0 - metrics.assistsPerGame) * 8)),
                    tags: [.decisionMaking, .passing]
                ),
                FocusCandidate(
                    title: "Control the boards",
                    why: "Rebounding can create extra possessions and reduce opponent second chances.",
                    action: "Add contact box-out drills and outlet transitions in every practice.",
                    priority: isBig ? max(7, Int((8.0 - metrics.reboundsPerGame) * 8)) : max(4, Int((4.0 - metrics.reboundsPerGame) * 8)),
                    tags: [.rebounding, .conditioning]
                ),
                FocusCandidate(
                    title: "Defend without fouling",
                    why: "High foul rate reduces available minutes and defensive stability.",
                    action: "Work on closeout angles and vertical contests with controlled contact.",
                    priority: max(4, Int((metrics.foulsPerGame - 2.5) * 10)),
                    tags: [.perimeterDefense, .conditioning]
                ),
                FocusCandidate(
                    title: "Disrupt more possessions",
                    why: "Steal and deflection activity can turn defense into transition points.",
                    action: "Train anticipation drills from shell defense and deny passing lane reps.",
                    priority: isGuard ? max(3, Int((1.8 - metrics.stealsPerGame) * 10)) : max(2, Int((1.2 - metrics.stealsPerGame) * 8)),
                    tags: [.perimeterDefense, .decisionMaking]
                ),
            ]
        } else {
            let isGoalkeeper = position == .goalkeeper
            let isDefender = [.defender, .leftBack, .rightBack, .centerBack].contains(position)
            let isMidfielder = [.midfielder, .defensiveMidfielder, .centralMidfielder, .attackingMidfielder, .leftMidfielder, .rightMidfielder].contains(position)
            let isForward = [.forward, .striker, .leftWing, .rightWing].contains(position)

            return [
                FocusCandidate(
                    title: "Improve chance conversion",
                    why: "Finishing efficiency can be lifted with sharper final-third execution.",
                    action: "Use first-touch and one-touch finishing drills from central and half-space entries.",
                    priority: max(6, Int((0.45 - metrics.primaryEfficiency) * 120)),
                    tags: [.finishing, .firstTouch]
                ),
                FocusCandidate(
                    title: "Speed up passing decisions",
                    why: "Higher passing volume improves control and chance creation.",
                    action: "Run timed rondos with scanning cues and two-touch limits.",
                    priority: isMidfielder ? max(6, Int((35.0 - metrics.passesPerGame) * 3)) : max(3, Int((20.0 - metrics.passesPerGame) * 2)),
                    tags: [.passing, .decisionMaking]
                ),
                FocusCandidate(
                    title: "Win more defensive actions",
                    why: "Tackles and interceptions help stop attacks earlier.",
                    action: "Practice body orientation, timing, and intercept triggers in transition games.",
                    priority: isDefender ? max(6, Int((6.0 - metrics.defensiveActionsPerGame) * 8)) : max(3, Int((3.0 - metrics.defensiveActionsPerGame) * 6)),
                    tags: [.tackling, .conditioning]
                ),
                FocusCandidate(
                    title: "Stay disciplined out of possession",
                    why: "Fouls and cards can break team structure and game control.",
                    action: "Use controlled 1v1 defending drills focused on angle and patience.",
                    priority: max(4, Int((metrics.foulsPerGame + metrics.cardsPerGame) * 8)),
                    tags: [.decisionMaking, .tackling]
                ),
                FocusCandidate(
                    title: "Sharpen goalkeeping fundamentals",
                    why: "Cleaner handling and positioning reduce second-chance opportunities.",
                    action: "Add reaction saves, handling sequences, and distribution patterns each session.",
                    priority: isGoalkeeper ? max(7, Int((4.0 - metrics.savesPerGame) * 8)) : 1,
                    tags: [.goalkeeping, .passing]
                ),
                FocusCandidate(
                    title: "Develop final-third impact",
                    why: "More goals and assists increase match influence.",
                    action: "Practice combination play in and around the box with quick support runs.",
                    priority: isForward ? max(7, Int((2.0 - metrics.primaryProductionPerGame) * 10)) : max(3, Int((1.0 - metrics.assistsPerGame) * 8)),
                    tags: [.finishing, .passing]
                ),
            ]
        }
    }

    private func defaultCandidates(for sport: SoccerPosition.SupportedSport) -> [FocusCandidate] {
        if sport == .basketball {
            return [
                FocusCandidate(
                    title: "Build game-speed conditioning",
                    why: "Late-game decisions and mechanics improve with better conditioning.",
                    action: "Add two interval conditioning blocks each week tied to ball handling or shooting.",
                    priority: 1,
                    tags: [.conditioning, .ballHandling]
                ),
                FocusCandidate(
                    title: "Refine shooting mechanics",
                    why: "Consistent mechanics stabilize efficiency across game pressure.",
                    action: "Track 100 form-focused reps across game spots over each practice cycle.",
                    priority: 1,
                    tags: [.shooting]
                ),
                FocusCandidate(
                    title: "Improve decision timing",
                    why: "Faster reads create cleaner offense and fewer mistakes.",
                    action: "Use constrained small-sided games with short shot clocks.",
                    priority: 1,
                    tags: [.decisionMaking]
                ),
            ]
        }

        return [
            FocusCandidate(
                title: "Improve match conditioning",
                why: "Consistent intensity supports technical execution over 90 minutes.",
                action: "Run interval-based conditioning with the ball 2-3 times each week.",
                priority: 1,
                tags: [.conditioning]
            ),
            FocusCandidate(
                title: "Sharpen first touch",
                why: "Better first touch creates more time and better passing options.",
                action: "Add first-touch receiving circuits with directional control every session.",
                priority: 1,
                tags: [.firstTouch, .passing]
            ),
            FocusCandidate(
                title: "Increase game scanning",
                why: "Pre-scan habits improve decision speed and quality under pressure.",
                action: "Use scan-before-receive constraints in rondos and positional games.",
                priority: 1,
                tags: [.decisionMaking]
            ),
        ]
    }

    // MARK: - Metrics

    private func recentCompletedGameStats(for player: Person, limit: Int) -> [PersonGameStats] {
        (player.gameStats ?? [])
            .filter { $0.game?.isCompleted == true }
            .sorted {
                let leftDate = $0.game?.gameDate ?? .distantPast
                let rightDate = $1.game?.gameDate ?? .distantPast
                if leftDate == rightDate { return $0.id.uuidString < $1.id.uuidString }
                return leftDate > rightDate
            }
            .prefix(limit)
            .map { $0 }
    }

    private func buildPlayerMetrics(from samples: [PersonGameStats], sport: SoccerPosition.SupportedSport) -> PlayerMetrics {
        guard !samples.isEmpty else {
            return PlayerMetrics(
                primaryProductionPerGame: 0,
                primaryEfficiency: 0,
                secondaryEfficiency: 0,
                tertiaryEfficiency: 0,
                reboundsPerGame: 0,
                assistsPerGame: 0,
                turnoversPerGame: 0,
                stealsPerGame: 0,
                passesPerGame: 0,
                defensiveActionsPerGame: 0,
                foulsPerGame: 0,
                cardsPerGame: 0,
                savesPerGame: 0
            )
        }

        let gameCount = Double(samples.count)

        if sport == .basketball {
            let points = samples.reduce(0) { $0 + $1.totalPoints }
            let rebounds = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "DREB") + $1.aggregatedCount(forName: "OREB") }
            let assists = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "AST") }
            let turnovers = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "TO") }
            let steals = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "STL") }
            let fouls = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "PF") }

            let twoMade = samples.reduce(0) { $0 + $1.aggregatedMade(forName: "2PT") }
            let twoMiss = samples.reduce(0) { $0 + $1.aggregatedMissed(forName: "2PT") }
            let threeMade = samples.reduce(0) { $0 + $1.aggregatedMade(forName: "3PT") }
            let threeMiss = samples.reduce(0) { $0 + $1.aggregatedMissed(forName: "3PT") }
            let ftMade = samples.reduce(0) { $0 + $1.aggregatedMade(forName: "FT") }
            let ftMiss = samples.reduce(0) { $0 + $1.aggregatedMissed(forName: "FT") }

            let fgMade = twoMade + threeMade
            let fgAtt = fgMade + twoMiss + threeMiss
            let threeAtt = threeMade + threeMiss
            let ftAtt = ftMade + ftMiss

            return PlayerMetrics(
                primaryProductionPerGame: Double(points) / gameCount,
                primaryEfficiency: fgAtt > 0 ? Double(fgMade) / Double(fgAtt) : 0,
                secondaryEfficiency: threeAtt > 0 ? Double(threeMade) / Double(threeAtt) : 0,
                tertiaryEfficiency: ftAtt > 0 ? Double(ftMade) / Double(ftAtt) : 0,
                reboundsPerGame: Double(rebounds) / gameCount,
                assistsPerGame: Double(assists) / gameCount,
                turnoversPerGame: Double(turnovers) / gameCount,
                stealsPerGame: Double(steals) / gameCount,
                passesPerGame: 0,
                defensiveActionsPerGame: Double(steals) / gameCount,
                foulsPerGame: Double(fouls) / gameCount,
                cardsPerGame: 0,
                savesPerGame: 0
            )
        } else {
            let goals = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "GOL") }
            let assists = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "AST") }
            let passes = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "PAS") }
            let tackles = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "TKL") }
            let interceptions = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "INT") }
            let saves = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "SAV") }
            let fouls = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "FLS") }
            let cards = samples.reduce(0) { $0 + $1.aggregatedCount(forName: "YC") + $1.aggregatedCount(forName: "RC") }

            let sotMade = samples.reduce(0) { $0 + $1.aggregatedMade(forName: "SOT") }
            let sotMissed = samples.reduce(0) { $0 + $1.aggregatedMissed(forName: "SOT") }
            let sotAttempts = sotMade + sotMissed

            return PlayerMetrics(
                primaryProductionPerGame: Double(goals) / gameCount,
                primaryEfficiency: sotAttempts > 0 ? Double(sotMade) / Double(sotAttempts) : 0,
                secondaryEfficiency: 0,
                tertiaryEfficiency: 0,
                reboundsPerGame: 0,
                assistsPerGame: Double(assists) / gameCount,
                turnoversPerGame: 0,
                stealsPerGame: 0,
                passesPerGame: Double(passes) / gameCount,
                defensiveActionsPerGame: Double(tackles + interceptions) / gameCount,
                foulsPerGame: Double(fouls) / gameCount,
                cardsPerGame: Double(cards) / gameCount,
                savesPerGame: Double(saves) / gameCount
            )
        }
    }

    private func resolvedPrimaryPosition(for player: Person, sport: SoccerPosition.SupportedSport) -> SoccerPosition? {
        let membershipPosition = (player.teamMemberships ?? [])
            .filter { membership in
                membership.isActive &&
                SoccerPosition.SupportedSport.from(sportName: membership.team?.sport?.name) == sport
            }
            .compactMap(\.primaryPosition)
            .first

        if let membershipPosition {
            return membershipPosition
        }

        let personPosition = player.positionAssignments.primaryPosition
        if personPosition?.supportedSport == sport {
            return personPosition
        }

        return nil
    }

    private func inferredSport(for game: Game) -> SoccerPosition.SupportedSport {
        SoccerPosition.SupportedSport.from(sportName: game.sport?.name)
    }

    private func inferredSport(for player: Person) -> SoccerPosition.SupportedSport {
        let latestSport = (player.gameStats ?? [])
            .compactMap { stats -> (Date, String?)? in
                guard let game = stats.game else { return nil }
                return (game.gameDate, game.sport?.name)
            }
            .sorted { $0.0 > $1.0 }
            .first?.1

        if let latestSport {
            return SoccerPosition.SupportedSport.from(sportName: latestSport)
        }

        if let membershipSport = (player.teamMemberships ?? [])
            .first(where: { $0.isActive })?.team?.sport?.name {
            return SoccerPosition.SupportedSport.from(sportName: membershipSport)
        }

        if let positionSport = player.positionAssignments.primaryPosition?.supportedSport {
            return positionSport
        }

        return .basketball
    }

    // MARK: - Resources

    private func resources(for tags: [ResourceTag], sport: SoccerPosition.SupportedSport) -> [CoachingResourceLink] {
        var links: [CoachingResourceLink] = []
        for tag in tags {
            links.append(contentsOf: resourceLibrary(for: sport)[tag] ?? [])
        }

        if links.isEmpty {
            links.append(contentsOf: defaultResources(for: sport))
        }

        var unique: [CoachingResourceLink] = []
        var seen = Set<String>()
        for link in links {
            let key = link.url.absoluteString
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(link)
            }
        }
        return Array(unique.prefix(3))
    }

    private func defaultResources(for sport: SoccerPosition.SupportedSport) -> [CoachingResourceLink] {
        if sport == .basketball {
            return [
                CoachingResourceLink(title: "Basketball Skill Workouts (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+skill+workout"),
                CoachingResourceLink(title: "USA Basketball Drills", urlString: "https://www.usab.com/youth/development/drills"),
            ]
        }
        return [
            CoachingResourceLink(title: "Soccer Training Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+training+drills"),
            CoachingResourceLink(title: "FIFA Training Centre", urlString: "https://www.fifatrainingcentre.com"),
        ]
    }

    private func resourceLibrary(for sport: SoccerPosition.SupportedSport) -> [ResourceTag: [CoachingResourceLink]] {
        if sport == .basketball {
            return [
                .shooting: [
                    CoachingResourceLink(title: "Basketball Shooting Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+shooting+drills"),
                    CoachingResourceLink(title: "Breakthrough Basketball Shooting Drills", urlString: "https://www.breakthroughbasketball.com/drills/shooting-drills.html"),
                ],
                .freeThrows: [
                    CoachingResourceLink(title: "Free Throw Routine Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+free+throw+routine"),
                    CoachingResourceLink(title: "USA Basketball Free Throw Tips", urlString: "https://www.usab.com/youth/development/drills"),
                ],
                .ballHandling: [
                    CoachingResourceLink(title: "Ball Handling Under Pressure (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+ball+handling+pressure+drills"),
                    CoachingResourceLink(title: "Handle Life Training Library", urlString: "https://www.handlelife.com"),
                ],
                .decisionMaking: [
                    CoachingResourceLink(title: "Pick and Roll Reads (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+pick+and+roll+reads"),
                    CoachingResourceLink(title: "NBA Jr. Coaching Resources", urlString: "https://jr.nba.com/coaches-resources"),
                ],
                .rebounding: [
                    CoachingResourceLink(title: "Rebounding Technique Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+rebounding+drills"),
                    CoachingResourceLink(title: "Breakthrough Rebounding Drills", urlString: "https://www.breakthroughbasketball.com/drills/rebounding-drills.html"),
                ],
                .perimeterDefense: [
                    CoachingResourceLink(title: "Defensive Footwork Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+defensive+footwork+drills"),
                    CoachingResourceLink(title: "USA Basketball Defense Drills", urlString: "https://www.usab.com/youth/development/drills"),
                ],
                .finishing: [
                    CoachingResourceLink(title: "Finishing at the Rim (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+finishing+at+the+rim+drills"),
                    CoachingResourceLink(title: "Pro Tips: Finishing", urlString: "https://www.breakthroughbasketball.com/fundamentals/"),
                ],
                .conditioning: [
                    CoachingResourceLink(title: "Basketball Conditioning Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+conditioning+drills"),
                    CoachingResourceLink(title: "NFHS Conditioning Guidelines", urlString: "https://www.nfhs.org"),
                ],
                .passing: [
                    CoachingResourceLink(title: "Basketball Passing Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=basketball+passing+drills"),
                    CoachingResourceLink(title: "Jr. NBA Skill Curriculum", urlString: "https://jr.nba.com"),
                ],
            ]
        }

        return [
            .finishing: [
                CoachingResourceLink(title: "Soccer Finishing Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+finishing+drills"),
                CoachingResourceLink(title: "FIFA Training Centre: Finishing", urlString: "https://www.fifatrainingcentre.com/en/training-tools/skill-training-games.php"),
            ],
            .firstTouch: [
                CoachingResourceLink(title: "First Touch Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+first+touch+drills"),
                CoachingResourceLink(title: "UEFA Training Ground", urlString: "https://www.uefa.com/trainingground/"),
            ],
            .passing: [
                CoachingResourceLink(title: "Passing and Rondo Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+passing+rondo+drills"),
                CoachingResourceLink(title: "FIFA Training Centre: Passing", urlString: "https://www.fifatrainingcentre.com"),
            ],
            .tackling: [
                CoachingResourceLink(title: "Defending and Tackling Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+defending+tackling+drills"),
                CoachingResourceLink(title: "United Soccer Coaches Education", urlString: "https://unitedsoccercoaches.org/education/"),
            ],
            .goalkeeping: [
                CoachingResourceLink(title: "Goalkeeper Handling Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+goalkeeper+drills"),
                CoachingResourceLink(title: "FIFA Goalkeeper Resources", urlString: "https://www.fifatrainingcentre.com"),
            ],
            .decisionMaking: [
                CoachingResourceLink(title: "Soccer Scanning and Decision Making (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+scanning+decision+making"),
                CoachingResourceLink(title: "The FA Learning", urlString: "https://www.thefa.com/learning"),
            ],
            .conditioning: [
                CoachingResourceLink(title: "Soccer Conditioning with Ball (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+conditioning+drills+with+ball"),
                CoachingResourceLink(title: "FIFA Fitness Resources", urlString: "https://www.fifa.com/football-development"),
            ],
            .shooting: [
                CoachingResourceLink(title: "Shooting Technique Drills (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+shooting+technique+drills"),
                CoachingResourceLink(title: "FIFA Training Centre", urlString: "https://www.fifatrainingcentre.com"),
            ],
            .ballHandling: [
                CoachingResourceLink(title: "1v1 Dribbling Moves (YouTube)", urlString: "https://www.youtube.com/results?search_query=soccer+1v1+dribbling+drills"),
                CoachingResourceLink(title: "US Soccer Coaching Education", urlString: "https://www.ussoccer.com/coaching"),
            ],
        ]
    }

}
