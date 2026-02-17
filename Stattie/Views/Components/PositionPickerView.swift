import SwiftUI

/// A simple multi-select view for choosing positions
/// If one position is selected, that's the player's position
/// If multiple are selected, they'll confirm which one when starting a shift
struct PositionPickerView: View {
    @Binding var assignments: PositionAssignments
    let sportName: String?
    @State private var showingPicker = false

    init(assignments: Binding<PositionAssignments>, sportName: String? = nil) {
        self._assignments = assignments
        self.sportName = sportName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if assignments.isEmpty {
                Button {
                    showingPicker = true
                } label: {
                    HStack {
                        Text("Select Position")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                ForEach(assignments.assignments) { assignment in
                    HStack {
                        Image(systemName: assignment.position.iconName)
                            .foregroundStyle(.accent)
                            .frame(width: 24)

                        Text(assignment.position.displayName)

                        Spacer()

                        Button {
                            withAnimation {
                                assignments.removePosition(assignment.position)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if assignments.assignments.count > 1 {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("You'll choose position when starting a shift")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                Button {
                    showingPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.accent)
                        Text("Add Position")
                            .foregroundStyle(.accent)
                    }
                }
                .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showingPicker) {
            SimplePositionSelectionSheet(assignments: $assignments, sportName: sportName)
        }
    }
}

/// Simple multi-select sheet for positions - no percentage sliders
struct SimplePositionSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var assignments: PositionAssignments
    let sportName: String?

    @State private var selectedPositions: Set<SoccerPosition> = []

    private var supportedSport: SoccerPosition.SupportedSport {
        SoccerPosition.supportedSport(for: sportName)
    }

    private var availableCategories: [SoccerPosition.PositionCategory] {
        SoccerPosition.categories(for: supportedSport)
    }

    private var availablePositions: Set<SoccerPosition> {
        Set(SoccerPosition.positions(for: supportedSport))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableCategories) { category in
                    Section(category.rawValue) {
                        ForEach(category.positions) { position in
                            Button {
                                togglePosition(position)
                            } label: {
                                HStack {
                                    Image(systemName: position.iconName)
                                        .foregroundStyle(.accent)
                                        .frame(width: 24)

                                    Text(position.displayName)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text(position.shortName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if selectedPositions.contains(position) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.accent)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if selectedPositions.count > 1 {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Multiple positions selected. You'll confirm which position when starting a shift.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Positions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        savePositions()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load existing positions
                selectedPositions = Set(
                    assignments.assignments
                        .map { $0.position }
                        .filter { availablePositions.contains($0) }
                )
            }
        }
    }

    private func togglePosition(_ position: SoccerPosition) {
        if selectedPositions.contains(position) {
            selectedPositions.remove(position)
        } else {
            selectedPositions.insert(position)
        }
    }

    private func savePositions() {
        // Clear existing and add selected positions with equal distribution
        assignments = PositionAssignments()
        let positions = SoccerPosition.allCases.filter { selectedPositions.contains($0) && availablePositions.contains($0) }

        if positions.count == 1 {
            assignments.addPosition(positions[0], percentage: 100)
        } else if positions.count > 1 {
            // Equal distribution
            let perPosition = 100 / positions.count
            let remainder = 100 % positions.count

            for (index, position) in positions.enumerated() {
                // Give first position any remainder to ensure 100% total
                let pct = index == 0 ? perPosition + remainder : perPosition
                assignments.addPosition(position, percentage: pct)
            }
        }
    }
}

/// Compact inline position picker for forms
struct InlinePositionPicker: View {
    @Binding var assignments: PositionAssignments
    let sportName: String?
    @State private var showingPicker = false

    init(assignments: Binding<PositionAssignments>, sportName: String? = nil) {
        self._assignments = assignments
        self.sportName = sportName
    }

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack {
                Text("Position")
                    .foregroundStyle(.primary)
                Spacer()
                if assignments.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    Text(assignments.shortDisplayText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            SimplePositionSelectionSheet(assignments: $assignments, sportName: sportName)
        }
    }
}

#Preview("Position Picker") {
    struct PreviewWrapper: View {
        @State var assignments = PositionAssignments()

        var body: some View {
            Form {
                Section("Position") {
                    PositionPickerView(assignments: $assignments)
                }
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Inline Picker") {
    struct PreviewWrapper: View {
        @State var assignments = PositionAssignments(assignments: [
            PositionAssignment(position: .defender, percentage: 50),
            PositionAssignment(position: .midfielder, percentage: 50)
        ])

        var body: some View {
            Form {
                InlinePositionPicker(assignments: $assignments)
            }
        }
    }

    return PreviewWrapper()
}
