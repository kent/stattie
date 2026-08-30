import Foundation

/// Parent-friendly coverage for major sports in Canada, the US, and Europe.
/// Basketball and soccer keep their customized seed arrays and tracking UIs;
/// this catalog describes the other sports and the position-specific filters
/// used by generic tracking.
enum StatRole: String, Hashable, CaseIterable {
    case shared
    case goalie
    case skater
    case batter
    case pitcher
    case catcher
    case fielder
    case quarterback
    case rusher
    case receiver
    case offensiveLine
    case defense
    case kicker
    case punter
    case attack
    case midfield
    case volleyballOffense
    case volleyballDefense
    case rugbyForward
    case rugbyBack
    case cricketBatter
    case cricketBowler
    case wicketkeeper
}

struct CatalogStatSpec: Equatable, Identifiable {
    let name: String
    let shortName: String
    let category: String
    let hasMadeAndMissed: Bool
    let pointValue: Int
    let sortOrder: Int
    let iconName: String
    let roles: Set<StatRole>

    var id: String { shortName }

    init(
        name: String,
        shortName: String,
        category: String,
        hasMadeAndMissed: Bool = false,
        pointValue: Int = 0,
        sortOrder: Int,
        iconName: String,
        roles: Set<StatRole> = [.shared]
    ) {
        self.name = name
        self.shortName = shortName
        self.category = category
        self.hasMadeAndMissed = hasMadeAndMissed
        self.pointValue = pointValue
        self.sortOrder = sortOrder
        self.iconName = iconName
        self.roles = roles
    }
}

enum CatalogScoreKind: Equatable {
    case points
    case count(String)
    case made(String)
}

struct SportProfile: Identifiable, Equatable {
    let name: String
    let iconName: String
    let summary: String
    let isTeamSport: Bool
    let usesCustomTracking: Bool
    let usesCustomSeed: Bool
    let regions: [String]
    let primaryScore: CatalogScoreKind
    let primaryScoreLabel: String
    let highlightShortNames: [String]
    let stats: [CatalogStatSpec]

    var id: String { name }

    func visibleStats(for roles: Set<StatRole>) -> [CatalogStatSpec] {
        guard !roles.isEmpty else { return stats }
        return stats.filter { spec in
            spec.roles.contains(.shared) || !spec.roles.isDisjoint(with: roles)
        }
    }

    func spec(shortName: String) -> CatalogStatSpec? {
        stats.first { $0.shortName == shortName }
    }
}

enum SportCatalog {
    static let all: [SportProfile] = [
        basketball,
        soccer,
        iceHockey,
        baseball,
        softball,
        americanFootball,
        canadianFootball,
        lacrosse,
        volleyball,
        rugby,
        handball,
        fieldHockey,
        cricket,
        waterPolo,
        tennis,
        golf,
        wrestling,
        curling,
    ]

    static var seedableSports: [SportProfile] {
        all.filter { !$0.usesCustomSeed }
    }

    static func profile(named name: String?) -> SportProfile? {
        guard let name, !name.isEmpty else { return nil }
        return all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    static func roles(for positions: [SoccerPosition]) -> Set<StatRole> {
        Set(positions.flatMap(\.statRoles))
    }

    static func visibleDefinitions(
        sportName: String?,
        definitions: [StatDefinition],
        positions: [SoccerPosition]
    ) -> [StatDefinition] {
        guard let profile = profile(named: sportName), !profile.usesCustomTracking else {
            return definitions
        }
        let roles = roles(for: positions)
        let allowed = Set(profile.visibleStats(for: roles).map(\.shortName))
        return definitions.filter { allowed.contains($0.shortName) }
    }

    static func primaryScoreValue(
        sportName: String?,
        points: Int,
        made: (String) -> Int,
        count: (String) -> Int
    ) -> Int? {
        guard let profile = profile(named: sportName) else { return nil }
        switch profile.primaryScore {
        case .points:
            return points
        case .count(let shortName):
            return count(shortName)
        case .made(let shortName):
            return made(shortName)
        }
    }
}

// MARK: - Existing customized sports (metadata only)

private extension SportCatalog {
    static let basketball = SportProfile(
        name: "Basketball",
        iconName: "basketball.fill",
        summary: "Track shots, rebounds, assists & more",
        isTeamSport: true,
        usesCustomTracking: true,
        usesCustomSeed: true,
        regions: ["US", "Canada", "Europe"],
        primaryScore: .points,
        primaryScoreLabel: "Points",
        highlightShortNames: ["2PT", "3PT", "FT", "AST"],
        stats: []
    )

    static let soccer = SportProfile(
        name: "Soccer",
        iconName: "soccerball",
        summary: "Track goals, saves, passes & more",
        isTeamSport: true,
        usesCustomTracking: true,
        usesCustomSeed: true,
        regions: ["US", "Canada", "Europe"],
        primaryScore: .count("GOL"),
        primaryScoreLabel: "Goals",
        highlightShortNames: ["GOL", "AST", "SAV"],
        stats: []
    )

    static let tennis = SportProfile(
        name: "Tennis",
        iconName: "tennisball.fill",
        summary: "Track aces, winners & errors — no team needed",
        isTeamSport: false,
        usesCustomTracking: false,
        usesCustomSeed: true,
        regions: ["US", "Canada", "Europe"],
        primaryScore: .count("ACE"),
        primaryScoreLabel: "Aces",
        highlightShortNames: ["ACE", "WIN", "UE"],
        stats: []
    )

    static let golf = SportProfile(
        name: "Golf",
        iconName: "figure.golf",
        summary: "Track fairways, greens & putts — no team needed",
        isTeamSport: false,
        usesCustomTracking: false,
        usesCustomSeed: true,
        regions: ["US", "Canada", "Europe"],
        primaryScore: .count("PUT"),
        primaryScoreLabel: "Putts",
        highlightShortNames: ["FWY", "GIR", "PUT"],
        stats: []
    )
}

// MARK: - Ice Hockey

private extension SportCatalog {
    static let iceHockey = SportProfile(
        name: "Ice Hockey",
        iconName: "figure.hockey",
        summary: "Skater and goalie stats for rink games",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Canada", "US", "Europe"],
        primaryScore: .count("G"),
        primaryScoreLabel: "Goals",
        highlightShortNames: ["G", "A", "SOG", "SV"],
        stats: [
            CatalogStatSpec(name: "Goal", shortName: "G", category: "scoring", sortOrder: 0, iconName: "scope", roles: [.shared, .skater, .goalie]),
            CatalogStatSpec(name: "Assist", shortName: "A", category: "scoring", sortOrder: 1, iconName: "arrow.triangle.branch", roles: [.shared, .skater, .goalie]),
            CatalogStatSpec(name: "Shot on Goal", shortName: "SOG", category: "offense", hasMadeAndMissed: true, sortOrder: 2, iconName: "circle.circle", roles: [.skater]),
            CatalogStatSpec(name: "Hit", shortName: "HIT", category: "physical", sortOrder: 3, iconName: "bolt.fill", roles: [.skater]),
            CatalogStatSpec(name: "Blocked Shot", shortName: "BLK", category: "defense", sortOrder: 4, iconName: "shield.fill", roles: [.skater]),
            CatalogStatSpec(name: "Takeaway", shortName: "TKA", category: "defense", sortOrder: 5, iconName: "hand.raised.fill", roles: [.skater]),
            CatalogStatSpec(name: "Giveaway", shortName: "GVA", category: "other", sortOrder: 6, iconName: "arrow.uturn.backward", roles: [.skater]),
            CatalogStatSpec(name: "Faceoff", shortName: "FO", category: "offense", hasMadeAndMissed: true, sortOrder: 7, iconName: "circle.grid.cross", roles: [.skater]),
            CatalogStatSpec(name: "Penalty Minute", shortName: "PIM", category: "other", sortOrder: 8, iconName: "clock.badge.exclamationmark", roles: [.shared]),
            CatalogStatSpec(name: "Save", shortName: "SV", category: "goalie", sortOrder: 9, iconName: "hand.raised.square.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Goal Against", shortName: "GA", category: "goalie", sortOrder: 10, iconName: "xmark.circle.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Shot Faced", shortName: "SA", category: "goalie", sortOrder: 11, iconName: "target", roles: [.goalie]),
            CatalogStatSpec(name: "Shutout", shortName: "SO", category: "goalie", sortOrder: 12, iconName: "star.fill", roles: [.goalie]),
        ]
    )
}

// MARK: - Baseball / Softball

private extension SportCatalog {
    static let baseballFamilyStats: [CatalogStatSpec] = [
        CatalogStatSpec(name: "Single", shortName: "1B", category: "batting", sortOrder: 0, iconName: "1.circle.fill", roles: [.batter]),
        CatalogStatSpec(name: "Double", shortName: "2B", category: "batting", sortOrder: 1, iconName: "2.circle.fill", roles: [.batter]),
        CatalogStatSpec(name: "Triple", shortName: "3B", category: "batting", sortOrder: 2, iconName: "3.circle.fill", roles: [.batter]),
        CatalogStatSpec(name: "Home Run", shortName: "HR", category: "batting", sortOrder: 3, iconName: "baseball.fill", roles: [.batter]),
        CatalogStatSpec(name: "Walk", shortName: "BB", category: "batting", sortOrder: 4, iconName: "figure.walk", roles: [.batter]),
        CatalogStatSpec(name: "Strikeout", shortName: "K", category: "batting", sortOrder: 5, iconName: "xmark.circle.fill", roles: [.batter]),
        CatalogStatSpec(name: "Hit By Pitch", shortName: "HBP", category: "batting", sortOrder: 6, iconName: "exclamationmark.triangle.fill", roles: [.batter]),
        CatalogStatSpec(name: "Run", shortName: "R", category: "batting", sortOrder: 7, iconName: "flag.fill", roles: [.batter]),
        CatalogStatSpec(name: "RBI", shortName: "RBI", category: "batting", sortOrder: 8, iconName: "person.3.fill", roles: [.batter]),
        CatalogStatSpec(name: "Stolen Base", shortName: "SB", category: "batting", hasMadeAndMissed: true, sortOrder: 9, iconName: "figure.run", roles: [.batter]),
        CatalogStatSpec(name: "Sacrifice", shortName: "SAC", category: "batting", sortOrder: 10, iconName: "arrow.up.right", roles: [.batter]),
        CatalogStatSpec(name: "Putout", shortName: "PO", category: "fielding", sortOrder: 11, iconName: "hand.raised.fill", roles: [.fielder, .catcher]),
        CatalogStatSpec(name: "Fielding Assist", shortName: "FA", category: "fielding", sortOrder: 12, iconName: "arrow.triangle.branch", roles: [.fielder, .catcher]),
        CatalogStatSpec(name: "Error", shortName: "E", category: "fielding", sortOrder: 13, iconName: "xmark.octagon.fill", roles: [.fielder, .catcher, .pitcher]),
        CatalogStatSpec(name: "Out Recorded", shortName: "OUT", category: "pitching", sortOrder: 14, iconName: "stop.circle.fill", roles: [.pitcher]),
        CatalogStatSpec(name: "Strikeout Thrown", shortName: "SO", category: "pitching", sortOrder: 15, iconName: "bolt.fill", roles: [.pitcher]),
        CatalogStatSpec(name: "Walk Allowed", shortName: "BBA", category: "pitching", sortOrder: 16, iconName: "figure.walk.motion", roles: [.pitcher]),
            CatalogStatSpec(name: "Hit Allowed", shortName: "HA", category: "pitching", sortOrder: 17, iconName: "baseball.fill", roles: [.pitcher]),
        CatalogStatSpec(name: "Earned Run", shortName: "ER", category: "pitching", sortOrder: 18, iconName: "minus.circle.fill", roles: [.pitcher]),
        CatalogStatSpec(name: "Wild Pitch", shortName: "WP", category: "pitching", sortOrder: 19, iconName: "tornado", roles: [.pitcher]),
        CatalogStatSpec(name: "Hit Batter", shortName: "HB", category: "pitching", sortOrder: 20, iconName: "exclamationmark.circle.fill", roles: [.pitcher]),
        CatalogStatSpec(name: "Passed Ball", shortName: "PB", category: "catching", sortOrder: 21, iconName: "hand.raised.slash.fill", roles: [.catcher]),
        CatalogStatSpec(name: "Caught Stealing", shortName: "CS", category: "catching", sortOrder: 22, iconName: "hand.thumbsup.fill", roles: [.catcher]),
            CatalogStatSpec(name: "Stolen Base Allowed", shortName: "SBA", category: "catching", sortOrder: 23, iconName: "figure.run", roles: [.catcher]),
    ]

    static let baseball = SportProfile(
        name: "Baseball",
        iconName: "figure.baseball",
        summary: "Separate batting, pitching, and catching buttons",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["US", "Canada"],
        primaryScore: .count("R"),
        primaryScoreLabel: "Runs",
        highlightShortNames: ["1B", "HR", "RBI", "SO"],
        stats: baseballFamilyStats
    )

    static let softball = SportProfile(
        name: "Softball",
        iconName: "figure.softball",
        summary: "Batting, pitching, and catching for the diamond",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["US", "Canada"],
        primaryScore: .count("R"),
        primaryScoreLabel: "Runs",
        highlightShortNames: ["1B", "HR", "RBI", "SO"],
        stats: baseballFamilyStats
    )
}

// MARK: - Football family

private extension SportCatalog {
    static func footballStats(includeRouge: Bool) -> [CatalogStatSpec] {
        var stats: [CatalogStatSpec] = [
            CatalogStatSpec(name: "Pass Completion", shortName: "CMP", category: "passing", hasMadeAndMissed: true, sortOrder: 0, iconName: "arrow.forward.circle.fill", roles: [.quarterback]),
            CatalogStatSpec(name: "Passing Touchdown", shortName: "PTD", category: "passing", sortOrder: 1, iconName: "football.fill", roles: [.quarterback]),
            CatalogStatSpec(name: "Interception Thrown", shortName: "INTT", category: "passing", sortOrder: 2, iconName: "xmark.circle.fill", roles: [.quarterback]),
            CatalogStatSpec(name: "Sack Taken", shortName: "SKT", category: "passing", sortOrder: 3, iconName: "arrow.down.circle.fill", roles: [.quarterback]),
            CatalogStatSpec(name: "Rush", shortName: "RUSH", category: "rushing", sortOrder: 4, iconName: "figure.run", roles: [.quarterback, .rusher]),
            CatalogStatSpec(name: "Rushing Touchdown", shortName: "RTD", category: "rushing", sortOrder: 5, iconName: "flag.fill", roles: [.quarterback, .rusher]),
            CatalogStatSpec(name: "Fumble", shortName: "FUM", category: "other", sortOrder: 6, iconName: "exclamationmark.triangle.fill", roles: [.quarterback, .rusher, .receiver]),
            CatalogStatSpec(name: "Reception", shortName: "REC", category: "receiving", hasMadeAndMissed: true, sortOrder: 7, iconName: "hand.raised.fill", roles: [.receiver, .rusher]),
            CatalogStatSpec(name: "Receiving Touchdown", shortName: "CTD", category: "receiving", sortOrder: 8, iconName: "star.fill", roles: [.receiver, .rusher]),
            CatalogStatSpec(name: "Drop", shortName: "DRP", category: "receiving", sortOrder: 9, iconName: "xmark.octagon.fill", roles: [.receiver]),
            CatalogStatSpec(name: "Pancake Block", shortName: "PAN", category: "oline", sortOrder: 10, iconName: "square.stack.fill", roles: [.offensiveLine]),
            CatalogStatSpec(name: "Sack Allowed", shortName: "SKA", category: "oline", sortOrder: 11, iconName: "shield.slash.fill", roles: [.offensiveLine]),
            CatalogStatSpec(name: "Holding", shortName: "HLD", category: "oline", sortOrder: 12, iconName: "hand.raised.fill", roles: [.offensiveLine]),
            CatalogStatSpec(name: "Tackle", shortName: "TKL", category: "defense", sortOrder: 13, iconName: "figure.fall", roles: [.defense]),
            CatalogStatSpec(name: "Tackle for Loss", shortName: "TFL", category: "defense", sortOrder: 14, iconName: "arrow.down.right.circle.fill", roles: [.defense]),
            CatalogStatSpec(name: "Sack", shortName: "SACK", category: "defense", sortOrder: 15, iconName: "bolt.fill", roles: [.defense]),
            CatalogStatSpec(name: "Interception", shortName: "INT", category: "defense", sortOrder: 16, iconName: "hand.raised.square.fill", roles: [.defense]),
            CatalogStatSpec(name: "Pass Breakup", shortName: "PBU", category: "defense", sortOrder: 17, iconName: "hand.raised.fill", roles: [.defense]),
            CatalogStatSpec(name: "Forced Fumble", shortName: "FF", category: "defense", sortOrder: 18, iconName: "burst.fill", roles: [.defense]),
            CatalogStatSpec(name: "Fumble Recovery", shortName: "FR", category: "defense", sortOrder: 19, iconName: "checkmark.circle.fill", roles: [.defense]),
            CatalogStatSpec(name: "Defensive Touchdown", shortName: "DTD", category: "defense", sortOrder: 20, iconName: "star.circle.fill", roles: [.defense]),
            CatalogStatSpec(name: "Field Goal", shortName: "FG", category: "kicking", hasMadeAndMissed: true, sortOrder: 21, iconName: "flag.fill", roles: [.kicker]),
            CatalogStatSpec(name: "Extra Point", shortName: "XP", category: "kicking", hasMadeAndMissed: true, sortOrder: 22, iconName: "plus.circle.fill", roles: [.kicker]),
            CatalogStatSpec(name: "Kickoff", shortName: "KO", category: "kicking", sortOrder: 23, iconName: "arrow.up.forward.circle.fill", roles: [.kicker]),
            CatalogStatSpec(name: "Touchback", shortName: "TB", category: "kicking", sortOrder: 24, iconName: "stop.fill", roles: [.kicker, .punter]),
            CatalogStatSpec(name: "Punt", shortName: "PUNT", category: "punting", sortOrder: 25, iconName: "arrow.up.right.circle.fill", roles: [.punter]),
            CatalogStatSpec(name: "Inside the 20", shortName: "IN20", category: "punting", sortOrder: 26, iconName: "target", roles: [.punter]),
        ]
        if includeRouge {
            stats.append(
                CatalogStatSpec(name: "Rouge", shortName: "RG", category: "kicking", sortOrder: 27, iconName: "1.circle.fill", roles: [.kicker, .punter])
            )
        }
        return stats
    }

    static let americanFootball = SportProfile(
        name: "American Football",
        iconName: "figure.american.football",
        summary: "QB, skill, line, defense, and specialist buttons",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["US"],
        primaryScore: .count("PTD"),
        primaryScoreLabel: "Pass TDs",
        highlightShortNames: ["CMP", "RUSH", "REC", "TKL"],
        stats: footballStats(includeRouge: false)
    )

    static let canadianFootball = SportProfile(
        name: "Canadian Football",
        iconName: "football.fill",
        summary: "CFL-style tracking including the rouge",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Canada"],
        primaryScore: .count("PTD"),
        primaryScoreLabel: "Pass TDs",
        highlightShortNames: ["CMP", "REC", "TKL", "RG"],
        stats: footballStats(includeRouge: true)
    )
}

// MARK: - Other team sports

private extension SportCatalog {
    static let lacrosse = SportProfile(
        name: "Lacrosse",
        iconName: "figure.lacrosse",
        summary: "Attack, midfield, defense, and goalie stats",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Canada", "US"],
        primaryScore: .count("G"),
        primaryScoreLabel: "Goals",
        highlightShortNames: ["G", "A", "GB", "SV"],
        stats: [
            CatalogStatSpec(name: "Goal", shortName: "G", category: "scoring", sortOrder: 0, iconName: "scope", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Assist", shortName: "A", category: "scoring", sortOrder: 1, iconName: "arrow.triangle.branch", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Shot", shortName: "SH", category: "offense", hasMadeAndMissed: true, sortOrder: 2, iconName: "circle.circle", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Ground Ball", shortName: "GB", category: "other", sortOrder: 3, iconName: "circle.fill", roles: [.shared]),
            CatalogStatSpec(name: "Caused Turnover", shortName: "CT", category: "defense", sortOrder: 4, iconName: "hand.raised.fill", roles: [.defense, .midfield]),
            CatalogStatSpec(name: "Turnover", shortName: "TO", category: "other", sortOrder: 5, iconName: "arrow.uturn.backward", roles: [.shared]),
            CatalogStatSpec(name: "Faceoff", shortName: "FO", category: "other", hasMadeAndMissed: true, sortOrder: 6, iconName: "circle.grid.cross", roles: [.midfield]),
            CatalogStatSpec(name: "Save", shortName: "SV", category: "goalie", sortOrder: 7, iconName: "hand.raised.square.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Goal Against", shortName: "GA", category: "goalie", sortOrder: 8, iconName: "xmark.circle.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Clear", shortName: "CLR", category: "goalie", hasMadeAndMissed: true, sortOrder: 9, iconName: "arrow.up.right.circle.fill", roles: [.goalie, .defense]),
        ]
    )

    static let volleyball = SportProfile(
        name: "Volleyball",
        iconName: "figure.volleyball",
        summary: "Kills, setting, serving, and libero defense",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["US", "Canada", "Europe"],
        primaryScore: .count("KIL"),
        primaryScoreLabel: "Kills",
        highlightShortNames: ["KIL", "AST", "ACE", "DIG"],
        stats: [
            CatalogStatSpec(name: "Kill", shortName: "KIL", category: "attack", sortOrder: 0, iconName: "bolt.fill", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Attack Error", shortName: "AE", category: "attack", sortOrder: 1, iconName: "xmark.circle.fill", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Attack Attempt", shortName: "ATT", category: "attack", sortOrder: 2, iconName: "arrow.up.circle.fill", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Assist", shortName: "AST", category: "setting", sortOrder: 3, iconName: "arrow.triangle.branch", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Ace", shortName: "ACE", category: "serve", sortOrder: 4, iconName: "star.fill", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Serve Error", shortName: "SE", category: "serve", sortOrder: 5, iconName: "exclamationmark.triangle.fill", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Block", shortName: "BLK", category: "block", sortOrder: 6, iconName: "hand.raised.fill", roles: [.volleyballOffense]),
            CatalogStatSpec(name: "Dig", shortName: "DIG", category: "defense", sortOrder: 7, iconName: "arrow.down.circle.fill", roles: [.volleyballDefense, .volleyballOffense]),
            CatalogStatSpec(name: "Reception", shortName: "RCP", category: "defense", hasMadeAndMissed: true, sortOrder: 8, iconName: "hand.point.up.left.fill", roles: [.volleyballDefense]),
        ]
    )

    static let rugby = SportProfile(
        name: "Rugby",
        iconName: "sportscourt.fill",
        summary: "Tries, tackles, and set-piece work for 15s or league",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Europe", "Canada"],
        primaryScore: .count("TRY"),
        primaryScoreLabel: "Tries",
        highlightShortNames: ["TRY", "CON", "TKL"],
        stats: [
            CatalogStatSpec(name: "Try", shortName: "TRY", category: "scoring", sortOrder: 0, iconName: "flag.fill", roles: [.shared]),
            CatalogStatSpec(name: "Conversion", shortName: "CON", category: "scoring", hasMadeAndMissed: true, sortOrder: 1, iconName: "checkmark.circle.fill", roles: [.rugbyBack]),
            CatalogStatSpec(name: "Penalty Goal", shortName: "PEN", category: "scoring", hasMadeAndMissed: true, sortOrder: 2, iconName: "target", roles: [.rugbyBack]),
            CatalogStatSpec(name: "Drop Goal", shortName: "DG", category: "scoring", hasMadeAndMissed: true, sortOrder: 3, iconName: "arrow.up.circle.fill", roles: [.rugbyBack]),
            CatalogStatSpec(name: "Carry", shortName: "CRY", category: "offense", sortOrder: 4, iconName: "figure.run", roles: [.shared]),
            CatalogStatSpec(name: "Tackle", shortName: "TKL", category: "defense", sortOrder: 5, iconName: "figure.fall", roles: [.shared]),
            CatalogStatSpec(name: "Turnover Won", shortName: "TOW", category: "defense", sortOrder: 6, iconName: "hand.raised.fill", roles: [.rugbyForward, .rugbyBack]),
            CatalogStatSpec(name: "Lineout Win", shortName: "LOW", category: "setpiece", hasMadeAndMissed: true, sortOrder: 7, iconName: "arrow.up.square.fill", roles: [.rugbyForward]),
            CatalogStatSpec(name: "Scrum Win", shortName: "SCW", category: "setpiece", hasMadeAndMissed: true, sortOrder: 8, iconName: "square.stack.3d.up.fill", roles: [.rugbyForward]),
            CatalogStatSpec(name: "Penalty Conceded", shortName: "PC", category: "other", sortOrder: 9, iconName: "exclamationmark.triangle.fill", roles: [.shared]),
        ]
    )

    static let handball = SportProfile(
        name: "Handball",
        iconName: "figure.handball",
        summary: "Court goals, 7-meters, and goalkeeper saves",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Europe"],
        primaryScore: .count("G"),
        primaryScoreLabel: "Goals",
        highlightShortNames: ["G", "AST", "SV"],
        stats: [
            CatalogStatSpec(name: "Goal", shortName: "G", category: "scoring", sortOrder: 0, iconName: "scope", roles: [.shared]),
            CatalogStatSpec(name: "Assist", shortName: "AST", category: "offense", sortOrder: 1, iconName: "arrow.triangle.branch", roles: [.shared]),
            CatalogStatSpec(name: "Shot", shortName: "SH", category: "offense", hasMadeAndMissed: true, sortOrder: 2, iconName: "circle.circle", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "7-Meter", shortName: "7M", category: "scoring", hasMadeAndMissed: true, sortOrder: 3, iconName: "7.circle.fill", roles: [.attack]),
            CatalogStatSpec(name: "Steal", shortName: "STL", category: "defense", sortOrder: 4, iconName: "hand.raised.fill", roles: [.defense, .midfield]),
            CatalogStatSpec(name: "Block", shortName: "BLK", category: "defense", sortOrder: 5, iconName: "shield.fill", roles: [.defense]),
            CatalogStatSpec(name: "2-Minute Suspension", shortName: "2M", category: "other", sortOrder: 6, iconName: "clock.badge.exclamationmark", roles: [.shared]),
            CatalogStatSpec(name: "Save", shortName: "SV", category: "goalie", sortOrder: 7, iconName: "hand.raised.square.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Goal Against", shortName: "GA", category: "goalie", sortOrder: 8, iconName: "xmark.circle.fill", roles: [.goalie]),
        ]
    )

    static let fieldHockey = SportProfile(
        name: "Field Hockey",
        iconName: "figure.hockey",
        summary: "Goals, penalty corners, and keeper saves",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Europe", "Canada"],
        primaryScore: .count("G"),
        primaryScoreLabel: "Goals",
        highlightShortNames: ["G", "PC", "SV"],
        stats: [
            CatalogStatSpec(name: "Goal", shortName: "G", category: "scoring", sortOrder: 0, iconName: "scope", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Assist", shortName: "AST", category: "offense", sortOrder: 1, iconName: "arrow.triangle.branch", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Shot", shortName: "SH", category: "offense", hasMadeAndMissed: true, sortOrder: 2, iconName: "circle.circle", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Penalty Corner", shortName: "PC", category: "offense", sortOrder: 3, iconName: "righttriangle.fill", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Tackle", shortName: "TKL", category: "defense", sortOrder: 4, iconName: "figure.fall", roles: [.defense, .midfield]),
            CatalogStatSpec(name: "Interception", shortName: "INT", category: "defense", sortOrder: 5, iconName: "hand.raised.fill", roles: [.defense, .midfield]),
            CatalogStatSpec(name: "Green Card", shortName: "GC", category: "other", sortOrder: 6, iconName: "rectangle.fill", roles: [.shared]),
            CatalogStatSpec(name: "Yellow Card", shortName: "YC", category: "other", sortOrder: 7, iconName: "rectangle.fill", roles: [.shared]),
            CatalogStatSpec(name: "Red Card", shortName: "RC", category: "other", sortOrder: 8, iconName: "rectangle.fill", roles: [.shared]),
            CatalogStatSpec(name: "Save", shortName: "SV", category: "goalie", sortOrder: 9, iconName: "hand.raised.square.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Goal Against", shortName: "GA", category: "goalie", sortOrder: 10, iconName: "xmark.circle.fill", roles: [.goalie]),
        ]
    )

    static let cricket = SportProfile(
        name: "Cricket",
        iconName: "sportscourt",
        summary: "Batting, bowling, and wicketkeeping are separate",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Europe", "Canada"],
        primaryScore: .count("RUN"),
        primaryScoreLabel: "Runs",
        highlightShortNames: ["RUN", "WKT", "CTH"],
        stats: [
            CatalogStatSpec(name: "Run", shortName: "RUN", category: "batting", sortOrder: 0, iconName: "figure.run", roles: [.cricketBatter]),
            CatalogStatSpec(name: "Four", shortName: "4S", category: "batting", sortOrder: 1, iconName: "4.circle.fill", roles: [.cricketBatter]),
            CatalogStatSpec(name: "Six", shortName: "6S", category: "batting", sortOrder: 2, iconName: "6.circle.fill", roles: [.cricketBatter]),
            CatalogStatSpec(name: "Ball Faced", shortName: "BF", category: "batting", sortOrder: 3, iconName: "circle.fill", roles: [.cricketBatter]),
            CatalogStatSpec(name: "Dismissal", shortName: "OUT", category: "batting", sortOrder: 4, iconName: "xmark.circle.fill", roles: [.cricketBatter]),
            CatalogStatSpec(name: "Wicket", shortName: "WKT", category: "bowling", sortOrder: 5, iconName: "target", roles: [.cricketBowler]),
            CatalogStatSpec(name: "Over", shortName: "OVR", category: "bowling", sortOrder: 6, iconName: "circle.grid.3x3.fill", roles: [.cricketBowler]),
            CatalogStatSpec(name: "Maiden", shortName: "MDN", category: "bowling", sortOrder: 7, iconName: "0.circle.fill", roles: [.cricketBowler]),
            CatalogStatSpec(name: "Run Conceded", shortName: "RC", category: "bowling", sortOrder: 8, iconName: "minus.circle.fill", roles: [.cricketBowler]),
            CatalogStatSpec(name: "Wide / No-Ball", shortName: "EXT", category: "bowling", sortOrder: 9, iconName: "exclamationmark.triangle.fill", roles: [.cricketBowler]),
            CatalogStatSpec(name: "Catch", shortName: "CTH", category: "fielding", sortOrder: 10, iconName: "hand.raised.fill", roles: [.shared, .wicketkeeper]),
            CatalogStatSpec(name: "Run Out", shortName: "RO", category: "fielding", sortOrder: 11, iconName: "figure.run", roles: [.shared]),
            CatalogStatSpec(name: "Stumping", shortName: "STP", category: "keeping", sortOrder: 12, iconName: "hand.thumbsup.fill", roles: [.wicketkeeper]),
            CatalogStatSpec(name: "Bye / Leg Bye", shortName: "BYE", category: "keeping", sortOrder: 13, iconName: "arrow.uturn.forward", roles: [.wicketkeeper]),
        ]
    )

    static let waterPolo = SportProfile(
        name: "Water Polo",
        iconName: "drop.circle.fill",
        summary: "Pool goals, exclusions, and goalie saves",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Europe", "US"],
        primaryScore: .count("G"),
        primaryScoreLabel: "Goals",
        highlightShortNames: ["G", "AST", "SV"],
        stats: [
            CatalogStatSpec(name: "Goal", shortName: "G", category: "scoring", sortOrder: 0, iconName: "scope", roles: [.attack]),
            CatalogStatSpec(name: "Assist", shortName: "AST", category: "offense", sortOrder: 1, iconName: "arrow.triangle.branch", roles: [.attack, .midfield]),
            CatalogStatSpec(name: "Shot", shortName: "SH", category: "offense", hasMadeAndMissed: true, sortOrder: 2, iconName: "circle.circle", roles: [.attack]),
            CatalogStatSpec(name: "Steal", shortName: "STL", category: "defense", sortOrder: 3, iconName: "hand.raised.fill", roles: [.defense, .midfield]),
            CatalogStatSpec(name: "Block", shortName: "BLK", category: "defense", sortOrder: 4, iconName: "shield.fill", roles: [.defense]),
            CatalogStatSpec(name: "Ejection Drawn", shortName: "EJD", category: "other", sortOrder: 5, iconName: "person.badge.minus", roles: [.attack]),
            CatalogStatSpec(name: "Ejection", shortName: "EJ", category: "other", sortOrder: 6, iconName: "exclamationmark.triangle.fill", roles: [.shared]),
            CatalogStatSpec(name: "Save", shortName: "SV", category: "goalie", sortOrder: 7, iconName: "hand.raised.square.fill", roles: [.goalie]),
            CatalogStatSpec(name: "Goal Against", shortName: "GA", category: "goalie", sortOrder: 8, iconName: "xmark.circle.fill", roles: [.goalie]),
        ]
    )

    static let wrestling = SportProfile(
        name: "Wrestling",
        iconName: "figure.wrestling",
        summary: "Takedowns, escapes, near-fall, and pins",
        isTeamSport: false,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["US", "Canada"],
        primaryScore: .count("TD"),
        primaryScoreLabel: "Takedowns",
        highlightShortNames: ["TD", "ESC", "PIN"],
        stats: [
            CatalogStatSpec(name: "Takedown", shortName: "TD", category: "scoring", pointValue: 2, sortOrder: 0, iconName: "figure.fall"),
            CatalogStatSpec(name: "Escape", shortName: "ESC", category: "scoring", pointValue: 1, sortOrder: 1, iconName: "figure.run"),
            CatalogStatSpec(name: "Reversal", shortName: "REV", category: "scoring", pointValue: 2, sortOrder: 2, iconName: "arrow.triangle.2.circlepath"),
            CatalogStatSpec(name: "Near Fall 2", shortName: "NF2", category: "scoring", pointValue: 2, sortOrder: 3, iconName: "2.circle.fill"),
            CatalogStatSpec(name: "Near Fall 3", shortName: "NF3", category: "scoring", pointValue: 3, sortOrder: 4, iconName: "3.circle.fill"),
            CatalogStatSpec(name: "Penalty Point", shortName: "PEN", category: "other", pointValue: 1, sortOrder: 5, iconName: "exclamationmark.triangle.fill"),
            CatalogStatSpec(name: "Pin", shortName: "PIN", category: "result", sortOrder: 6, iconName: "star.fill"),
            CatalogStatSpec(name: "Stall Warning", shortName: "STL", category: "other", sortOrder: 7, iconName: "clock.badge.exclamationmark"),
        ]
    )

    static let curling = SportProfile(
        name: "Curling",
        iconName: "sportscourt.fill",
        summary: "Draws, takeouts, and end scoring by position",
        isTeamSport: true,
        usesCustomTracking: false,
        usesCustomSeed: false,
        regions: ["Canada", "Europe"],
        primaryScore: .count("PTS"),
        primaryScoreLabel: "Points",
        highlightShortNames: ["DRW", "TKO", "PTS"],
        stats: [
            CatalogStatSpec(name: "Draw", shortName: "DRW", category: "shots", hasMadeAndMissed: true, sortOrder: 0, iconName: "circle.circle"),
            CatalogStatSpec(name: "Takeout", shortName: "TKO", category: "shots", hasMadeAndMissed: true, sortOrder: 1, iconName: "bolt.fill"),
            CatalogStatSpec(name: "Guard", shortName: "GRD", category: "shots", hasMadeAndMissed: true, sortOrder: 2, iconName: "shield.fill"),
            CatalogStatSpec(name: "Steal", shortName: "STL", category: "ends", sortOrder: 3, iconName: "hand.raised.fill"),
            CatalogStatSpec(name: "End Won", shortName: "END", category: "ends", sortOrder: 4, iconName: "checkmark.circle.fill"),
            CatalogStatSpec(name: "Points Scored", shortName: "PTS", category: "scoring", sortOrder: 5, iconName: "plus.circle.fill"),
        ]
    )
}
