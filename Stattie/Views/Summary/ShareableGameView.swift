import SwiftUI

struct ShareableGameView: View {
    let game: Game

    var sortedPersonStats: [PersonGameStats] {
        (game.personStats ?? [])
            .filter { pgs in
                let stats = pgs.stats ?? []
                return !stats.isEmpty && stats.contains { $0.total > 0 }
            }
            .sorted { ($0.person?.jerseyNumber ?? 0) < ($1.person?.jerseyNumber ?? 0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                if !game.opponent.isEmpty {
                    Text("vs \(game.opponent)")
                        .font(.title2.bold())
                }

                Text("\(game.totalPoints)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.accent)

                Text("Total Points")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(game.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: 12) {
                HStack {
                    Text("Person")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("PTS")
                        .font(.caption.bold())
                        .frame(width: 40)
                    Text("FG")
                        .font(.caption.bold())
                        .frame(width: 50)
                    Text("3PT")
                        .font(.caption.bold())
                        .frame(width: 50)
                    Text("FT")
                        .font(.caption.bold())
                        .frame(width: 50)
                    Text("REB")
                        .font(.caption.bold())
                        .frame(width: 40)
                }
                .foregroundStyle(.secondary)

                ForEach(sortedPersonStats, id: \.id) { pgs in
                    if let person = pgs.person {
                        PersonStatRow(person: person, stats: pgs)
                    }
                }
            }

            Divider()

            HStack {
                Image(systemName: "basketball.fill")
                Text("Tracked with Stattie")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white)
    }
}

struct PersonStatRow: View {
    let person: Person
    let stats: PersonGameStats

    private func statValue(for shortName: String) -> Stat? {
        (stats.stats ?? []).first { $0.definition?.shortName == shortName }
    }

    private var fg: String {
        let twoPoint = statValue(for: "2PT")
        let threePoint = statValue(for: "3PT")
        let made = (twoPoint?.made ?? 0) + (threePoint?.made ?? 0)
        let attempts = (twoPoint?.made ?? 0) + (twoPoint?.missed ?? 0) + (threePoint?.made ?? 0) + (threePoint?.missed ?? 0)
        return "\(made)/\(attempts)"
    }

    private var threePoint: String {
        guard let stat = statValue(for: "3PT") else { return "-" }
        return "\(stat.made)/\(stat.made + stat.missed)"
    }

    private var freeThrow: String {
        guard let stat = statValue(for: "FT") else { return "-" }
        return "\(stat.made)/\(stat.made + stat.missed)"
    }

    var body: some View {
        HStack {
            Text("#\(person.jerseyNumber) \(person.lastName)")
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(stats.totalPoints)")
                .font(.caption.bold())
                .frame(width: 40)

            Text(fg)
                .font(.caption)
                .frame(width: 50)

            Text(threePoint)
                .font(.caption)
                .frame(width: 50)

            Text(freeThrow)
                .font(.caption)
                .frame(width: 50)

            Text("\(stats.totalRebounds)")
                .font(.caption)
                .frame(width: 40)
        }
    }
}

#Preview {
    ShareableGameView(game: Game(opponent: "Lakers"))
        .frame(width: 400)
}
