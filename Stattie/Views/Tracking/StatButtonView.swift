import SwiftUI

struct ShootingStatButton: View {
    let definition: StatDefinition
    let made: Int
    let missed: Int
    let onMade: () -> Void
    let onMissed: () -> Void

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
                .accessibilityLabel("Record made \(definition.name)")
                .accessibilityHint("Current count: \(made) made out of \(attempts) attempts")

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
                .accessibilityLabel("Record missed \(definition.name)")
                .accessibilityHint("Current count: \(missed) missed out of \(attempts) attempts")
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
    let count: Int
    let onTap: () -> Void

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
        .accessibleStatButton(name: definition.name, value: count)
    }
}

struct RecordingStatButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    let undoAction: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void,
        undoAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
        self.undoAction = undoAction
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.headline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: action)
        .onLongPressGesture(minimumDuration: 0.45) {
            undoAction?()
        }
        .accessibilityLabel("\(title), current: \(subtitle)")
        .accessibilityHint(undoAction == nil ? "Double tap to record" : "Double tap to record. Long press to undo one.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .accessibilityActions {
            if let undoAction { Button("Undo one", action: undoAction) }
        }
    }
}


#Preview {
    VStack(spacing: 20) {
        ShootingStatButton(
            definition: StatDefinition(name: "2-Point Shot", shortName: "2PT", category: "shooting", hasMadeAndMissed: true, pointValue: 2),
            made: 0,
            missed: 0,
            onMade: {},
            onMissed: {}
        )

        CountStatButton(
            definition: StatDefinition(name: "Steal", shortName: "STL", category: "defense", iconName: "hand.raised.fill"),
            count: 0,
            onTap: {}
        )
    }
    .padding()
}
