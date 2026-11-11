import SwiftUI

/// The interactive stat board shared by live tracking and shift editing.
struct StatBoardView: View {
    let sport: Sport?
    /// Drives role-specific layout, such as a goalkeeper's saves headline.
    let position: SoccerPosition?
    /// Positions whose stats are shown. Empty shows every stat.
    let visiblePositions: [SoccerPosition]
    /// Values shown on the buttons and headline.
    let stats: any StatTotals
    /// Wider totals used for milestones and secondary figures.
    let contextStats: any StatTotals
    let isShiftScoped: Bool
    let record: (_ name: String, _ points: Int, _ mutation: StatMutation) -> Void
    let undo: (_ name: String, _ mutation: StatMutation) -> Void

    var body: some View {
        switch sport?.name ?? "" {
        case "Soccer": soccerBoard
        case "Basketball": basketballBoard
        default: genericBoard
        }
    }

    // MARK: - Basketball

    private var basketballBoard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(stats.totalPoints)")
                    .scaledFont(size: 56, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(.blue)
                Text(isShiftScoped ? "SHIFT PTS" : "PTS")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if contextStats.doubleDigitCategories >= 3 {
                    Label("Triple Double", systemImage: "star.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                } else if contextStats.doubleDigitCategories >= 2 {
                    Label("Double Double", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                madeButton("2 PTS", name: "2PT", points: 2, color: .blue)
                madeButton("3 PTS", name: "3PT", points: 3, color: .purple)
                madeButton("FT", name: "FT", points: 1, color: .orange)
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                missButton("2PT Miss", name: "2PT", points: 2)
                missButton("3PT Miss", name: "3PT", points: 3)
                missButton("FT Miss", name: "FT", points: 1)
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                countButton("D-REB", name: "DREB", color: .green)
                countButton("O-REB", name: "OREB", color: .teal)
                countButton("STEAL", name: "STL", color: .indigo)
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                countButton("ASSIST", name: "AST", color: .mint)
                countButton("FOUL", name: "PF", color: .red)
                countButton("TURNOVER", name: "TO", color: .brown)
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                countButton("MISSED DRIVE", name: "MD", color: .orange)
                countButton("BAD OFF", name: "BPO", color: .red)
                countButton("BAD DEF", name: "BPD", color: .pink)
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                countButton("SUCCESS DRIVE", name: "SD", color: .green)
                countButton("GREAT OFF", name: "GPO", color: .yellow)
                countButton("GREAT DEF", name: "GPD", color: .green)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Soccer

    private var isGoalkeeper: Bool { position?.isGoalkeeperRole == true }

    private var soccerBoard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(stats.totalCount(forName: isGoalkeeper ? "SAV" : "GOL"))")
                    .scaledFont(size: 56, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(isGoalkeeper ? .blue : .green)
                Text((isShiftScoped ? "SHIFT " : "") + (isGoalkeeper ? "SAVES" : "GOALS"))
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                let contextSaves = contextStats.totalCount(forName: "SAV")
                if !isGoalkeeper, contextSaves > 0 {
                    VStack(alignment: .trailing) {
                        Text("\(contextSaves)")
                            .font(.title.bold())
                            .foregroundStyle(.blue)
                        Text("Saves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            if shows("GOL") || shows("SOT") || shows("AST") {
                HStack(spacing: 10) {
                    if shows("GOL") { countButton("GOAL", name: "GOL", color: .green) }
                    if shows("SOT") { madeButton("SHOT", name: "SOT", points: 0, color: .teal) }
                    if shows("AST") { countButton("ASSIST", name: "AST", color: .mint) }
                }
                .padding(.horizontal)
            }

            if shows("SOT") {
                HStack(spacing: 8) {
                    missButton("Shot Off Target", name: "SOT", points: 0)
                }
                .padding(.horizontal)
            }

            if shows("SAV") || shows("TKL") || shows("INT") {
                HStack(spacing: 10) {
                    if shows("SAV") { countButton("SAVE", name: "SAV", color: .blue) }
                    if shows("TKL") { countButton("TACKLE", name: "TKL", color: .indigo) }
                    if shows("INT") { countButton("INT", name: "INT", color: .purple) }
                }
                .padding(.horizontal)
            }

            if shows("PAS") || shows("CRN") || shows("FLS") {
                HStack(spacing: 10) {
                    if shows("PAS") { countButton("PASS", name: "PAS", color: .cyan) }
                    if shows("CRN") { countButton("CORNER", name: "CRN", color: .orange) }
                    if shows("FLS") { countButton("FOUL", name: "FLS", color: .red) }
                }
                .padding(.horizontal)
            }

            if shows("YC") || shows("RC") {
                HStack(spacing: 10) {
                    if shows("YC") { countButton("YELLOW", name: "YC", color: .yellow) }
                    if shows("RC") { countButton("RED", name: "RC", color: .red) }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    private func shows(_ shortName: String) -> Bool {
        SportCatalog.showsStat(shortName, sportName: sport?.name, positions: visiblePositions)
    }

    // MARK: - Individual / Generic Sports

    private var visibleDefinitions: [StatDefinition] {
        SportCatalog.visibleDefinitions(
            sportName: sport?.name,
            definitions: sport?.sortedStatDefinitions ?? [],
            positions: visiblePositions
        )
    }

    private var primaryDefinition: StatDefinition? {
        if let profile = SportCatalog.profile(named: sport?.name) {
            switch profile.primaryScore {
            case .count(let shortName), .made(let shortName):
                return visibleDefinitions.first { $0.shortName == shortName }
                    ?? sport?.sortedStatDefinitions.first { $0.shortName == shortName }
            case .points:
                break
            }
        }
        return visibleDefinitions.first ?? sport?.sortedStatDefinitions.first
    }

    private var genericBoard: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let definition = primaryDefinition {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(definition.hasMadeAndMissed ? stats.totalMade(forName: definition.shortName) : stats.totalCount(forName: definition.shortName))")
                            .scaledFont(size: 56, weight: .bold, relativeTo: .largeTitle)
                            .foregroundStyle(.blue)
                        Text(definition.name.uppercased())
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                ForEach(visibleDefinitions.filter(\.hasMadeAndMissed), id: \.id) { definition in
                    ShootingStatButton(
                        definition: definition,
                        made: stats.totalMade(forName: definition.shortName),
                        missed: stats.totalMissed(forName: definition.shortName),
                        onMade: { record(definition.shortName, definition.pointValue, .made) },
                        onMissed: { record(definition.shortName, definition.pointValue, .missed) }
                    )
                    .padding(.horizontal)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(visibleDefinitions.filter { !$0.hasMadeAndMissed }, id: \.id) { definition in
                        CountStatButton(
                            definition: definition,
                            count: stats.totalCount(forName: definition.shortName),
                            onTap: { record(definition.shortName, 0, .count) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Buttons

    private func madeButton(_ title: String, name: String, points: Int, color: Color) -> RecordingStatButton {
        RecordingStatButton(
            title: title,
            subtitle: stats.madeString(forName: name),
            color: color,
            action: { record(name, points, .made) },
            undoAction: { undo(name, .made) }
        )
    }

    private func countButton(_ title: String, name: String, color: Color) -> RecordingStatButton {
        RecordingStatButton(
            title: title,
            subtitle: "\(stats.totalCount(forName: name))",
            color: color,
            action: { record(name, 0, .count) },
            undoAction: { undo(name, .count) }
        )
    }

    private func missButton(_ title: String, name: String, points: Int) -> MissButton {
        MissButton(
            title: title,
            action: { record(name, points, .missed) },
            undoAction: { undo(name, .missed) }
        )
    }
}
