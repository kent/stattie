import SwiftUI

struct ShootingStatButton: View {
    let definition: StatDefinition
    let stat: Stat?
    let onMade: () -> Void
    let onMissed: () -> Void

    private var made: Int { stat?.made ?? 0 }
    private var missed: Int { stat?.missed ?? 0 }
    private var attempts: Int { made + missed }
    private var percentage: String {
        guard attempts > 0 else { return "0%" }
        return String(format: "%.0f%%", Double(made) / Double(attempts) * 100)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(definition.name)
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(made)/\(attempts)")
                        .font(.title2.bold())
                    if definition.pointValue > 0 {
                        Text("\(made * definition.pointValue) pts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                Button {
                    onMade()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Made")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    onMissed()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Missed")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            HStack {
                ProgressView(value: attempts > 0 ? Double(made) / Double(attempts) : 0)
                    .tint(.accent)

                Text(percentage)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CountStatButton: View {
    let definition: StatDefinition
    let stat: Stat?
    let onTap: () -> Void

    private var count: Int { stat?.count ?? 0 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: definition.iconName)
                    .font(.title2)
                    .foregroundStyle(.accent)

                Text(definition.shortName)
                    .font(.headline)

                Text("\(count)")
                    .font(.title.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        ShootingStatButton(
            definition: StatDefinition(name: "2-Point Shot", shortName: "2PT", category: "shooting", hasMadeAndMissed: true, pointValue: 2),
            stat: nil,
            onMade: {},
            onMissed: {}
        )

        CountStatButton(
            definition: StatDefinition(name: "Steal", shortName: "STL", category: "defense", iconName: "hand.raised.fill"),
            stat: nil,
            onTap: {}
        )
    }
    .padding()
}
