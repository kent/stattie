import Foundation

/// Team positions for every supported sport.
/// Existing soccer and basketball raw values stay stable for saved assignments.
enum SoccerPosition: String, CaseIterable, Codable, Identifiable {
    case goalkeeper = "GK"
    case defender = "DEF"
    case leftBack = "LB"
    case rightBack = "RB"
    case centerBack = "CB"
    case midfielder = "MID"
    case defensiveMidfielder = "CDM"
    case centralMidfielder = "CM"
    case attackingMidfielder = "CAM"
    case leftMidfielder = "LM"
    case rightMidfielder = "RM"
    case forward = "FWD"
    case striker = "ST"
    case leftWing = "LW"
    case rightWing = "RW"

    case pointGuard = "PG"
    case shootingGuard = "SG"
    case smallForward = "SF"
    case powerForward = "PF"
    case center = "C"

    case hockeyGoalie = "H-G"
    case hockeyDefenseman = "H-D"
    case hockeyLeftDefense = "H-LD"
    case hockeyRightDefense = "H-RD"
    case hockeyCenter = "H-C"
    case hockeyLeftWing = "H-LW"
    case hockeyRightWing = "H-RW"
    case hockeyForward = "H-F"

    case baseballPitcher = "B-P"
    case baseballStarter = "B-SP"
    case baseballReliever = "B-RP"
    case baseballCloser = "B-CL"
    case baseballCatcher = "B-C"
    case baseballFirstBase = "B-1B"
    case baseballSecondBase = "B-2B"
    case baseballThirdBase = "B-3B"
    case baseballShortstop = "B-SS"
    case baseballLeftField = "B-LF"
    case baseballCenterField = "B-CF"
    case baseballRightField = "B-RF"
    case baseballDesignatedHitter = "B-DH"
    case baseballUtility = "B-UT"

    case footballQB = "F-QB"
    case footballRB = "F-RB"
    case footballFB = "F-FB"
    case footballWR = "F-WR"
    case footballTE = "F-TE"
    case footballSlotback = "F-SB"
    case footballOT = "F-OT"
    case footballOG = "F-OG"
    case footballCenter = "F-C"
    case footballDE = "F-DE"
    case footballDT = "F-DT"
    case footballLB = "F-LB"
    case footballCB = "F-CB"
    case footballS = "F-S"
    case footballK = "F-K"
    case footballP = "F-P"
    case footballLS = "F-LS"

    case lacrosseAttack = "L-A"
    case lacrosseMidfield = "L-M"
    case lacrosseDefense = "L-D"
    case lacrosseGoalie = "L-G"
    case lacrosseLSM = "L-LSM"
    case lacrosseFOGO = "L-FO"

    case volleyballSetter = "V-S"
    case volleyballOutside = "V-OH"
    case volleyballOpposite = "V-OPP"
    case volleyballMiddle = "V-MB"
    case volleyballLibero = "V-L"
    case volleyballDefensiveSpecialist = "V-DS"

    case rugbyProp = "R-PR"
    case rugbyHooker = "R-HK"
    case rugbyLock = "R-LK"
    case rugbyFlanker = "R-FL"
    case rugbyNumberEight = "R-8"
    case rugbyScrumHalf = "R-SH"
    case rugbyFlyHalf = "R-FH"
    case rugbyCentre = "R-CE"
    case rugbyWing = "R-W"
    case rugbyFullback = "R-FB"

    case handballGoalkeeper = "HB-GK"
    case handballLeftWing = "HB-LW"
    case handballLeftBack = "HB-LB"
    case handballCenterBack = "HB-CB"
    case handballRightBack = "HB-RB"
    case handballRightWing = "HB-RW"
    case handballPivot = "HB-P"

    case fieldHockeyGoalkeeper = "FH-GK"
    case fieldHockeyDefender = "FH-D"
    case fieldHockeyMidfielder = "FH-M"
    case fieldHockeyForward = "FH-F"

    case cricketBatter = "CR-BAT"
    case cricketBowler = "CR-BWL"
    case cricketAllRounder = "CR-AR"
    case cricketWicketkeeper = "CR-WK"

    case waterPoloGoalie = "WP-G"
    case waterPoloCenter = "WP-C"
    case waterPoloDriver = "WP-DR"
    case waterPoloWing = "WP-W"
    case waterPoloPoint = "WP-PT"

    case tennisSingles = "TN-S"
    case tennisDoubles = "TN-D"

    case curlingSkip = "CU-SK"
    case curlingVice = "CU-V"
    case curlingSecond = "CU-2"
    case curlingLead = "CU-LD"

    var id: String { rawValue }

    var displayName: String { meta.displayName }
    var shortName: String { meta.shortName }
    var iconName: String { meta.iconName }
    var category: PositionCategory { meta.category }
    var statRoles: Set<StatRole> { meta.roles }
    var isGoalkeeperRole: Bool { meta.isGoalkeeper }

    var supportedSport: SupportedSport { supportedSports.first ?? .soccer }

    var supportedSports: Set<SupportedSport> { meta.sports }

    static func supportedSport(for sportName: String?) -> SupportedSport {
        SupportedSport.from(sportName: sportName)
    }

    static func categories(for sport: SupportedSport) -> [PositionCategory] {
        PositionCategory.allCases.filter { $0.supportedSports.contains(sport) }
    }

    static func positions(for sport: SupportedSport) -> [SoccerPosition] {
        allCases.filter { $0.supportedSports.contains(sport) }
    }

    enum SupportedSport: String, Equatable, Hashable, CaseIterable {
        case soccer
        case basketball
        case iceHockey
        case baseball
        case softball
        case americanFootball
        case canadianFootball
        case lacrosse
        case volleyball
        case rugby
        case handball
        case fieldHockey
        case cricket
        case waterPolo
        case tennis
        case golf
        case wrestling
        case curling

        static func from(sportName: String?) -> SupportedSport {
            guard let name = sportName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !name.isEmpty else {
                return .soccer
            }
            if name.contains("basketball") { return .basketball }
            if name.contains("field hockey") { return .fieldHockey }
            if name.contains("ice hockey") || name == "hockey" { return .iceHockey }
            if name.contains("softball") { return .softball }
            if name.contains("baseball") { return .baseball }
            if name.contains("canadian football") { return .canadianFootball }
            if name.contains("american football") { return .americanFootball }
            if name.contains("soccer") { return .soccer }
            if name.contains("lacrosse") { return .lacrosse }
            if name.contains("volleyball") { return .volleyball }
            if name.contains("rugby") { return .rugby }
            if name.contains("handball") { return .handball }
            if name.contains("cricket") { return .cricket }
            if name.contains("water polo") { return .waterPolo }
            if name.contains("tennis") { return .tennis }
            if name.contains("golf") { return .golf }
            if name.contains("wrestling") { return .wrestling }
            if name.contains("curling") { return .curling }
            return .soccer
        }
    }

    enum PositionCategory: String, CaseIterable, Identifiable {
        case goalkeeper = "Goalkeeper"
        case defense = "Defense"
        case midfield = "Midfield"
        case attack = "Attack"
        case guards = "Guards"
        case forwards = "Forwards"
        case center = "Center"
        case hockeyGoalies = "Hockey Goalies"
        case hockeyDefense = "Hockey Defense"
        case hockeyForwards = "Hockey Forwards"
        case baseballPitchers = "Pitchers"
        case baseballCatchers = "Catchers"
        case baseballInfield = "Infield"
        case baseballOutfield = "Outfield"
        case baseballHitters = "Hitters"
        case footballOffense = "Offense"
        case footballLine = "Offensive Line"
        case footballDefense = "Defense Front"
        case footballSecondary = "Secondary"
        case footballSpecialists = "Specialists"
        case lacrossePositions = "Lacrosse"
        case volleyballFront = "Front Row"
        case volleyballBack = "Back Row"
        case rugbyForwards = "Forwards Pack"
        case rugbyBacks = "Backs"
        case handballCourt = "Court Players"
        case handballKeepers = "Handball Goalkeepers"
        case fieldHockeyRoles = "Field Hockey"
        case cricketRoles = "Cricket"
        case waterPoloRoles = "Water Polo"
        case tennisRoles = "Tennis"
        case curlingRoles = "Curling"

        var id: String { rawValue }

        var supportedSport: SupportedSport { supportedSports.first ?? .soccer }

        var supportedSports: Set<SupportedSport> {
            switch self {
            case .goalkeeper, .defense, .midfield, .attack:
                return [.soccer]
            case .guards, .forwards, .center:
                return [.basketball]
            case .hockeyGoalies, .hockeyDefense, .hockeyForwards:
                return [.iceHockey]
            case .baseballPitchers, .baseballCatchers, .baseballInfield, .baseballOutfield, .baseballHitters:
                return [.baseball, .softball]
            case .footballOffense, .footballLine, .footballDefense, .footballSecondary, .footballSpecialists:
                return [.americanFootball, .canadianFootball]
            case .lacrossePositions:
                return [.lacrosse]
            case .volleyballFront, .volleyballBack:
                return [.volleyball]
            case .rugbyForwards, .rugbyBacks:
                return [.rugby]
            case .handballCourt, .handballKeepers:
                return [.handball]
            case .fieldHockeyRoles:
                return [.fieldHockey]
            case .cricketRoles:
                return [.cricket]
            case .waterPoloRoles:
                return [.waterPolo]
            case .tennisRoles:
                return [.tennis]
            case .curlingRoles:
                return [.curling]
            }
        }

        var positions: [SoccerPosition] {
            SoccerPosition.allCases.filter { $0.category == self }
        }
    }
}

private struct PositionMeta {
    let displayName: String
    let shortName: String
    let sports: Set<SoccerPosition.SupportedSport>
    let category: SoccerPosition.PositionCategory
    let iconName: String
    let roles: Set<StatRole>
    let isGoalkeeper: Bool

    init(
        _ displayName: String,
        short: String,
        sports: Set<SoccerPosition.SupportedSport>,
        category: SoccerPosition.PositionCategory,
        icon: String,
        roles: Set<StatRole>,
        goalie: Bool = false
    ) {
        self.displayName = displayName
        self.shortName = short
        self.sports = sports
        self.category = category
        self.iconName = icon
        self.roles = roles
        self.isGoalkeeper = goalie
    }
}

private extension SoccerPosition {
    var meta: PositionMeta {
        switch self {
        case .goalkeeper:
            return PositionMeta("Goalkeeper", short: "GK", sports: [.soccer], category: .goalkeeper, icon: "hand.raised.fill", roles: [.goalie], goalie: true)
        case .defender:
            return PositionMeta("Defender", short: "DEF", sports: [.soccer], category: .defense, icon: "shield.fill", roles: [.defense])
        case .leftBack:
            return PositionMeta("Left Back", short: "LB", sports: [.soccer], category: .defense, icon: "shield.fill", roles: [.defense])
        case .rightBack:
            return PositionMeta("Right Back", short: "RB", sports: [.soccer], category: .defense, icon: "shield.fill", roles: [.defense])
        case .centerBack:
            return PositionMeta("Center Back", short: "CB", sports: [.soccer], category: .defense, icon: "shield.fill", roles: [.defense])
        case .midfielder:
            return PositionMeta("Midfielder", short: "MID", sports: [.soccer], category: .midfield, icon: "figure.run", roles: [.midfield])
        case .defensiveMidfielder:
            return PositionMeta("Defensive Mid", short: "CDM", sports: [.soccer], category: .midfield, icon: "figure.run", roles: [.midfield, .defense])
        case .centralMidfielder:
            return PositionMeta("Central Mid", short: "CM", sports: [.soccer], category: .midfield, icon: "figure.run", roles: [.midfield])
        case .attackingMidfielder:
            return PositionMeta("Attacking Mid", short: "CAM", sports: [.soccer], category: .midfield, icon: "figure.run", roles: [.midfield, .attack])
        case .leftMidfielder:
            return PositionMeta("Left Mid", short: "LM", sports: [.soccer], category: .midfield, icon: "figure.run", roles: [.midfield])
        case .rightMidfielder:
            return PositionMeta("Right Mid", short: "RM", sports: [.soccer], category: .midfield, icon: "figure.run", roles: [.midfield])
        case .forward:
            return PositionMeta("Forward", short: "FWD", sports: [.soccer], category: .attack, icon: "scope", roles: [.attack])
        case .striker:
            return PositionMeta("Striker", short: "ST", sports: [.soccer], category: .attack, icon: "scope", roles: [.attack])
        case .leftWing:
            return PositionMeta("Left Wing", short: "LW", sports: [.soccer], category: .attack, icon: "scope", roles: [.attack])
        case .rightWing:
            return PositionMeta("Right Wing", short: "RW", sports: [.soccer], category: .attack, icon: "scope", roles: [.attack])
        case .pointGuard:
            return PositionMeta("Point Guard", short: "PG", sports: [.basketball], category: .guards, icon: "figure.basketball", roles: [.shared])
        case .shootingGuard:
            return PositionMeta("Shooting Guard", short: "SG", sports: [.basketball], category: .guards, icon: "figure.basketball", roles: [.shared])
        case .smallForward:
            return PositionMeta("Small Forward", short: "SF", sports: [.basketball], category: .forwards, icon: "figure.run", roles: [.shared])
        case .powerForward:
            return PositionMeta("Power Forward", short: "PF", sports: [.basketball], category: .forwards, icon: "figure.run", roles: [.shared])
        case .center:
            return PositionMeta("Center", short: "C", sports: [.basketball], category: .center, icon: "person.fill", roles: [.shared])

        case .hockeyGoalie:
            return PositionMeta("Goalie", short: "G", sports: [.iceHockey], category: .hockeyGoalies, icon: "hand.raised.fill", roles: [.goalie], goalie: true)
        case .hockeyDefenseman:
            return PositionMeta("Defenseman", short: "D", sports: [.iceHockey], category: .hockeyDefense, icon: "shield.fill", roles: [.skater])
        case .hockeyLeftDefense:
            return PositionMeta("Left Defense", short: "LD", sports: [.iceHockey], category: .hockeyDefense, icon: "shield.fill", roles: [.skater])
        case .hockeyRightDefense:
            return PositionMeta("Right Defense", short: "RD", sports: [.iceHockey], category: .hockeyDefense, icon: "shield.fill", roles: [.skater])
        case .hockeyCenter:
            return PositionMeta("Center", short: "C", sports: [.iceHockey], category: .hockeyForwards, icon: "figure.hockey", roles: [.skater])
        case .hockeyLeftWing:
            return PositionMeta("Left Wing", short: "LW", sports: [.iceHockey], category: .hockeyForwards, icon: "figure.hockey", roles: [.skater])
        case .hockeyRightWing:
            return PositionMeta("Right Wing", short: "RW", sports: [.iceHockey], category: .hockeyForwards, icon: "figure.hockey", roles: [.skater])
        case .hockeyForward:
            return PositionMeta("Forward", short: "F", sports: [.iceHockey], category: .hockeyForwards, icon: "figure.hockey", roles: [.skater])

        case .baseballPitcher:
            return PositionMeta("Pitcher", short: "P", sports: [.baseball, .softball], category: .baseballPitchers, icon: "baseball.fill", roles: [.pitcher, .batter])
        case .baseballStarter:
            return PositionMeta("Starting Pitcher", short: "SP", sports: [.baseball, .softball], category: .baseballPitchers, icon: "baseball.fill", roles: [.pitcher, .batter])
        case .baseballReliever:
            return PositionMeta("Relief Pitcher", short: "RP", sports: [.baseball, .softball], category: .baseballPitchers, icon: "baseball.fill", roles: [.pitcher, .batter])
        case .baseballCloser:
            return PositionMeta("Closer", short: "CL", sports: [.baseball, .softball], category: .baseballPitchers, icon: "baseball.fill", roles: [.pitcher, .batter])
        case .baseballCatcher:
            return PositionMeta("Catcher", short: "C", sports: [.baseball, .softball], category: .baseballCatchers, icon: "hand.raised.fill", roles: [.catcher, .batter, .fielder])
        case .baseballFirstBase:
            return PositionMeta("First Base", short: "1B", sports: [.baseball, .softball], category: .baseballInfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballSecondBase:
            return PositionMeta("Second Base", short: "2B", sports: [.baseball, .softball], category: .baseballInfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballThirdBase:
            return PositionMeta("Third Base", short: "3B", sports: [.baseball, .softball], category: .baseballInfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballShortstop:
            return PositionMeta("Shortstop", short: "SS", sports: [.baseball, .softball], category: .baseballInfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballLeftField:
            return PositionMeta("Left Field", short: "LF", sports: [.baseball, .softball], category: .baseballOutfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballCenterField:
            return PositionMeta("Center Field", short: "CF", sports: [.baseball, .softball], category: .baseballOutfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballRightField:
            return PositionMeta("Right Field", short: "RF", sports: [.baseball, .softball], category: .baseballOutfield, icon: "baseball.fill", roles: [.fielder, .batter])
        case .baseballDesignatedHitter:
            return PositionMeta("Designated Hitter", short: "DH", sports: [.baseball], category: .baseballHitters, icon: "figure.baseball", roles: [.batter])
        case .baseballUtility:
            return PositionMeta("Utility", short: "UT", sports: [.baseball, .softball], category: .baseballHitters, icon: "person.2.fill", roles: [.batter, .fielder])

        case .footballQB:
            return PositionMeta("Quarterback", short: "QB", sports: [.americanFootball, .canadianFootball], category: .footballOffense, icon: "figure.american.football", roles: [.quarterback])
        case .footballRB:
            return PositionMeta("Running Back", short: "RB", sports: [.americanFootball, .canadianFootball], category: .footballOffense, icon: "figure.run", roles: [.rusher, .receiver])
        case .footballFB:
            return PositionMeta("Fullback", short: "FB", sports: [.americanFootball, .canadianFootball], category: .footballOffense, icon: "figure.run", roles: [.rusher, .receiver])
        case .footballWR:
            return PositionMeta("Wide Receiver", short: "WR", sports: [.americanFootball, .canadianFootball], category: .footballOffense, icon: "figure.run", roles: [.receiver])
        case .footballTE:
            return PositionMeta("Tight End", short: "TE", sports: [.americanFootball], category: .footballOffense, icon: "figure.american.football", roles: [.receiver])
        case .footballSlotback:
            return PositionMeta("Slotback", short: "SB", sports: [.canadianFootball], category: .footballOffense, icon: "figure.run", roles: [.receiver])
        case .footballOT:
            return PositionMeta("Offensive Tackle", short: "OT", sports: [.americanFootball, .canadianFootball], category: .footballLine, icon: "shield.fill", roles: [.offensiveLine])
        case .footballOG:
            return PositionMeta("Offensive Guard", short: "OG", sports: [.americanFootball, .canadianFootball], category: .footballLine, icon: "shield.fill", roles: [.offensiveLine])
        case .footballCenter:
            return PositionMeta("Center", short: "C", sports: [.americanFootball, .canadianFootball], category: .footballLine, icon: "person.fill", roles: [.offensiveLine])
        case .footballDE:
            return PositionMeta("Defensive End", short: "DE", sports: [.americanFootball, .canadianFootball], category: .footballDefense, icon: "shield.fill", roles: [.defense])
        case .footballDT:
            return PositionMeta("Defensive Tackle", short: "DT", sports: [.americanFootball, .canadianFootball], category: .footballDefense, icon: "shield.fill", roles: [.defense])
        case .footballLB:
            return PositionMeta("Linebacker", short: "LB", sports: [.americanFootball, .canadianFootball], category: .footballDefense, icon: "figure.fall", roles: [.defense])
        case .footballCB:
            return PositionMeta("Cornerback", short: "CB", sports: [.americanFootball, .canadianFootball], category: .footballSecondary, icon: "hand.raised.fill", roles: [.defense])
        case .footballS:
            return PositionMeta("Safety", short: "S", sports: [.americanFootball, .canadianFootball], category: .footballSecondary, icon: "eye.fill", roles: [.defense])
        case .footballK:
            return PositionMeta("Kicker", short: "K", sports: [.americanFootball, .canadianFootball], category: .footballSpecialists, icon: "flag.fill", roles: [.kicker])
        case .footballP:
            return PositionMeta("Punter", short: "P", sports: [.americanFootball, .canadianFootball], category: .footballSpecialists, icon: "arrow.up.right", roles: [.punter])
        case .footballLS:
            return PositionMeta("Long Snapper", short: "LS", sports: [.americanFootball], category: .footballSpecialists, icon: "arrow.down.circle.fill", roles: [.offensiveLine])

        case .lacrosseAttack:
            return PositionMeta("Attack", short: "A", sports: [.lacrosse], category: .lacrossePositions, icon: "scope", roles: [.attack])
        case .lacrosseMidfield:
            return PositionMeta("Midfield", short: "M", sports: [.lacrosse], category: .lacrossePositions, icon: "figure.run", roles: [.midfield, .attack])
        case .lacrosseDefense:
            return PositionMeta("Defense", short: "D", sports: [.lacrosse], category: .lacrossePositions, icon: "shield.fill", roles: [.defense])
        case .lacrosseGoalie:
            return PositionMeta("Goalie", short: "G", sports: [.lacrosse], category: .lacrossePositions, icon: "hand.raised.fill", roles: [.goalie], goalie: true)
        case .lacrosseLSM:
            return PositionMeta("Long-Stick Midfield", short: "LSM", sports: [.lacrosse], category: .lacrossePositions, icon: "shield.fill", roles: [.defense, .midfield])
        case .lacrosseFOGO:
            return PositionMeta("Faceoff Specialist", short: "FOGO", sports: [.lacrosse], category: .lacrossePositions, icon: "circle.grid.cross", roles: [.midfield])

        case .volleyballSetter:
            return PositionMeta("Setter", short: "S", sports: [.volleyball], category: .volleyballFront, icon: "arrow.triangle.branch", roles: [.volleyballOffense])
        case .volleyballOutside:
            return PositionMeta("Outside Hitter", short: "OH", sports: [.volleyball], category: .volleyballFront, icon: "figure.volleyball", roles: [.volleyballOffense, .volleyballDefense])
        case .volleyballOpposite:
            return PositionMeta("Opposite", short: "OPP", sports: [.volleyball], category: .volleyballFront, icon: "figure.volleyball", roles: [.volleyballOffense])
        case .volleyballMiddle:
            return PositionMeta("Middle Blocker", short: "MB", sports: [.volleyball], category: .volleyballFront, icon: "hand.raised.fill", roles: [.volleyballOffense])
        case .volleyballLibero:
            return PositionMeta("Libero", short: "L", sports: [.volleyball], category: .volleyballBack, icon: "shield.fill", roles: [.volleyballDefense])
        case .volleyballDefensiveSpecialist:
            return PositionMeta("Defensive Specialist", short: "DS", sports: [.volleyball], category: .volleyballBack, icon: "arrow.down.circle.fill", roles: [.volleyballDefense])

        case .rugbyProp:
            return PositionMeta("Prop", short: "PR", sports: [.rugby], category: .rugbyForwards, icon: "shield.fill", roles: [.rugbyForward])
        case .rugbyHooker:
            return PositionMeta("Hooker", short: "HK", sports: [.rugby], category: .rugbyForwards, icon: "shield.fill", roles: [.rugbyForward])
        case .rugbyLock:
            return PositionMeta("Lock", short: "LK", sports: [.rugby], category: .rugbyForwards, icon: "arrow.up.square.fill", roles: [.rugbyForward])
        case .rugbyFlanker:
            return PositionMeta("Flanker", short: "FL", sports: [.rugby], category: .rugbyForwards, icon: "figure.fall", roles: [.rugbyForward])
        case .rugbyNumberEight:
            return PositionMeta("Number 8", short: "8", sports: [.rugby], category: .rugbyForwards, icon: "8.circle.fill", roles: [.rugbyForward])
        case .rugbyScrumHalf:
            return PositionMeta("Scrum-half", short: "SH", sports: [.rugby], category: .rugbyBacks, icon: "arrow.triangle.branch", roles: [.rugbyBack])
        case .rugbyFlyHalf:
            return PositionMeta("Fly-half", short: "FH", sports: [.rugby], category: .rugbyBacks, icon: "flag.fill", roles: [.rugbyBack])
        case .rugbyCentre:
            return PositionMeta("Centre", short: "CE", sports: [.rugby], category: .rugbyBacks, icon: "figure.run", roles: [.rugbyBack])
        case .rugbyWing:
            return PositionMeta("Wing", short: "W", sports: [.rugby], category: .rugbyBacks, icon: "figure.run", roles: [.rugbyBack])
        case .rugbyFullback:
            return PositionMeta("Fullback", short: "FB", sports: [.rugby], category: .rugbyBacks, icon: "shield.fill", roles: [.rugbyBack])

        case .handballGoalkeeper:
            return PositionMeta("Goalkeeper", short: "GK", sports: [.handball], category: .handballKeepers, icon: "hand.raised.fill", roles: [.goalie], goalie: true)
        case .handballLeftWing:
            return PositionMeta("Left Wing", short: "LW", sports: [.handball], category: .handballCourt, icon: "scope", roles: [.attack])
        case .handballLeftBack:
            return PositionMeta("Left Back", short: "LB", sports: [.handball], category: .handballCourt, icon: "scope", roles: [.attack, .midfield])
        case .handballCenterBack:
            return PositionMeta("Center Back", short: "CB", sports: [.handball], category: .handballCourt, icon: "arrow.triangle.branch", roles: [.midfield])
        case .handballRightBack:
            return PositionMeta("Right Back", short: "RB", sports: [.handball], category: .handballCourt, icon: "scope", roles: [.attack, .midfield])
        case .handballRightWing:
            return PositionMeta("Right Wing", short: "RW", sports: [.handball], category: .handballCourt, icon: "scope", roles: [.attack])
        case .handballPivot:
            return PositionMeta("Pivot", short: "P", sports: [.handball], category: .handballCourt, icon: "person.fill", roles: [.attack])

        case .fieldHockeyGoalkeeper:
            return PositionMeta("Goalkeeper", short: "GK", sports: [.fieldHockey], category: .fieldHockeyRoles, icon: "hand.raised.fill", roles: [.goalie], goalie: true)
        case .fieldHockeyDefender:
            return PositionMeta("Defender", short: "D", sports: [.fieldHockey], category: .fieldHockeyRoles, icon: "shield.fill", roles: [.defense])
        case .fieldHockeyMidfielder:
            return PositionMeta("Midfielder", short: "M", sports: [.fieldHockey], category: .fieldHockeyRoles, icon: "figure.run", roles: [.midfield])
        case .fieldHockeyForward:
            return PositionMeta("Forward", short: "F", sports: [.fieldHockey], category: .fieldHockeyRoles, icon: "scope", roles: [.attack])

        case .cricketBatter:
            return PositionMeta("Batter", short: "BAT", sports: [.cricket], category: .cricketRoles, icon: "sportscourt", roles: [.cricketBatter])
        case .cricketBowler:
            return PositionMeta("Bowler", short: "BWL", sports: [.cricket], category: .cricketRoles, icon: "target", roles: [.cricketBowler])
        case .cricketAllRounder:
            return PositionMeta("All-rounder", short: "AR", sports: [.cricket], category: .cricketRoles, icon: "person.2.fill", roles: [.cricketBatter, .cricketBowler])
        case .cricketWicketkeeper:
            return PositionMeta("Wicket-keeper", short: "WK", sports: [.cricket], category: .cricketRoles, icon: "hand.raised.fill", roles: [.wicketkeeper, .cricketBatter])

        case .waterPoloGoalie:
            return PositionMeta("Goalie", short: "G", sports: [.waterPolo], category: .waterPoloRoles, icon: "hand.raised.fill", roles: [.goalie], goalie: true)
        case .waterPoloCenter:
            return PositionMeta("Center", short: "C", sports: [.waterPolo], category: .waterPoloRoles, icon: "person.fill", roles: [.attack])
        case .waterPoloDriver:
            return PositionMeta("Driver", short: "DR", sports: [.waterPolo], category: .waterPoloRoles, icon: "figure.run", roles: [.attack, .midfield])
        case .waterPoloWing:
            return PositionMeta("Wing", short: "W", sports: [.waterPolo], category: .waterPoloRoles, icon: "scope", roles: [.attack])
        case .waterPoloPoint:
            return PositionMeta("Point", short: "PT", sports: [.waterPolo], category: .waterPoloRoles, icon: "shield.fill", roles: [.defense, .midfield])

        case .tennisSingles:
            return PositionMeta("Singles", short: "S", sports: [.tennis], category: .tennisRoles, icon: "tennisball.fill", roles: [.shared])
        case .tennisDoubles:
            return PositionMeta("Doubles", short: "D", sports: [.tennis], category: .tennisRoles, icon: "person.2.fill", roles: [.shared])

        case .curlingSkip:
            return PositionMeta("Skip", short: "SK", sports: [.curling], category: .curlingRoles, icon: "flag.fill", roles: [.shared])
        case .curlingVice:
            return PositionMeta("Vice / Third", short: "V", sports: [.curling], category: .curlingRoles, icon: "person.fill", roles: [.shared])
        case .curlingSecond:
            return PositionMeta("Second", short: "2", sports: [.curling], category: .curlingRoles, icon: "2.circle.fill", roles: [.shared])
        case .curlingLead:
            return PositionMeta("Lead", short: "LD", sports: [.curling], category: .curlingRoles, icon: "1.circle.fill", roles: [.shared])
        }
    }
}

/// Represents a position assignment with a percentage of playing time
struct PositionAssignment: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var position: SoccerPosition
    var percentage: Int  // 0-100

    init(position: SoccerPosition, percentage: Int = 100) {
        self.position = position
        self.percentage = min(100, max(0, percentage))
    }

    var displayText: String {
        if percentage == 100 {
            return position.displayName
        } else {
            return "\(position.displayName) (\(percentage)%)"
        }
    }
}

/// A collection of position assignments that should sum to 100%
struct PositionAssignments: Codable, Equatable {
    var assignments: [PositionAssignment]

    init(assignments: [PositionAssignment] = []) {
        self.assignments = assignments
    }

    /// Creates a single position at 100%
    init(singlePosition: SoccerPosition) {
        self.assignments = [PositionAssignment(position: singlePosition, percentage: 100)]
    }

    /// Total percentage (should be 100 for a valid configuration)
    var totalPercentage: Int {
        assignments.reduce(0) { $0 + $1.percentage }
    }

    var isValid: Bool {
        !assignments.isEmpty && totalPercentage == 100
    }

    var isEmpty: Bool {
        assignments.isEmpty
    }

    /// Display string for all positions
    var displayText: String {
        if assignments.isEmpty {
            return ""
        }
        if assignments.count == 1 && assignments[0].percentage == 100 {
            return assignments[0].position.displayName
        }
        return assignments.map { $0.displayText }.joined(separator: " / ")
    }

    /// Short display with abbreviations
    var shortDisplayText: String {
        if assignments.isEmpty {
            return ""
        }
        if assignments.count == 1 && assignments[0].percentage == 100 {
            return assignments[0].position.shortName
        }
        return assignments.map { "\($0.position.shortName) \($0.percentage)%" }.joined(separator: " / ")
    }

    /// Primary position (highest percentage)
    var primaryPosition: SoccerPosition? {
        assignments.max(by: { $0.percentage < $1.percentage })?.position
    }

    /// Check if this is a goalie (any percentage as a keeper-style position)
    var includesGoalkeeper: Bool {
        assignments.contains { $0.position.isGoalkeeperRole }
    }

    var statRoles: Set<StatRole> {
        SportCatalog.roles(for: assignments.map(\.position))
    }

    mutating func addPosition(_ position: SoccerPosition, percentage: Int) {
        // Remove if already exists
        assignments.removeAll { $0.position == position }
        assignments.append(PositionAssignment(position: position, percentage: percentage))
    }

    mutating func removePosition(_ position: SoccerPosition) {
        assignments.removeAll { $0.position == position }
    }

    mutating func updatePercentage(for position: SoccerPosition, to percentage: Int) {
        if let index = assignments.firstIndex(where: { $0.position == position }) {
            assignments[index].percentage = min(100, max(0, percentage))
        }
    }

    /// Normalize percentages to sum to 100
    mutating func normalize() {
        guard !assignments.isEmpty else { return }
        let total = totalPercentage
        guard total > 0 else { return }

        // Simple proportional scaling
        let scale = 100.0 / Double(total)
        var sum = 0
        for i in 0..<(assignments.count - 1) {
            let scaled = Int(round(Double(assignments[i].percentage) * scale))
            assignments[i].percentage = scaled
            sum += scaled
        }
        // Last one gets remainder to ensure exactly 100
        assignments[assignments.count - 1].percentage = 100 - sum
    }
}

// MARK: - JSON Encoding/Decoding helpers for Person model

extension PositionAssignments {
    /// Encode to JSON string for storage
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode from JSON string
    static func fromJSON(_ json: String?) -> PositionAssignments {
        guard let json = json,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PositionAssignments.self, from: data) else {
            return PositionAssignments()
        }
        return decoded
    }
}
