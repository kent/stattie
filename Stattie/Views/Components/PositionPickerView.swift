import SwiftUI

/// A view for selecting soccer positions with support for split roles
struct PositionPickerView: View {
    @Binding var assignments: PositionAssignments
    @State private var showingPicker = false

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

                        if assignments.assignments.count > 1 {
                            Text("\(assignment.percentage)%")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

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
            PositionSelectionSheet(assignments: $assignments)
        }
    }
}

/// Sheet for selecting positions with percentages
struct PositionSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var assignments: PositionAssignments

    @State private var selectedPosition: SoccerPosition?
    @State private var percentage: Double = 100

    private var availablePositions: [SoccerPosition] {
        let existingPositions = Set(assignments.assignments.map { $0.position })
        return SoccerPosition.allCases.filter { !existingPositions.contains($0) }
    }

    private var remainingPercentage: Int {
        100 - assignments.totalPercentage
    }

    var body: some View {
        NavigationStack {
            List {
                if !assignments.isEmpty {
                    Section {
                        HStack {
                            Text("Remaining")
                            Spacer()
                            Text("\(remainingPercentage)%")
                                .foregroundStyle(remainingPercentage > 0 ? .accent : .secondary)
                        }
                    }
                }

                ForEach(SoccerPosition.PositionCategory.allCases, id: \.self) { category in
                    let categoryPositions = availablePositions.filter { $0.category == category }
                    if !categoryPositions.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryPositions) { position in
                                Button {
                                    selectedPosition = position
                                    percentage = Double(min(100, remainingPercentage > 0 ? remainingPercentage : 50))
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
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPosition) { position in
                PercentagePickerSheet(
                    position: position,
                    percentage: $percentage,
                    maxPercentage: remainingPercentage > 0 ? remainingPercentage : 100
                ) {
                    withAnimation {
                        assignments.addPosition(position, percentage: Int(percentage))
                    }
                    selectedPosition = nil
                }
            }
        }
    }
}

/// Sheet for selecting the percentage for a position
struct PercentagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let position: SoccerPosition
    @Binding var percentage: Double
    let maxPercentage: Int
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: position.iconName)
                        .font(.largeTitle)
                        .foregroundStyle(.accent)

                    Text(position.displayName)
                        .font(.title2.bold())
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    Text("Playing Time")
                        .font(.headline)

                    Text("\(Int(percentage))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.accent)

                    Slider(value: $percentage, in: 5...Double(max(5, maxPercentage)), step: 5)
                        .padding(.horizontal)

                    // Quick select buttons
                    HStack(spacing: 12) {
                        ForEach([25, 50, 75, 100], id: \.self) { pct in
                            if pct <= maxPercentage {
                                Button("\(pct)%") {
                                    percentage = Double(pct)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()

                Spacer()

                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Add Position")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Set Percentage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Compact inline position picker for forms
struct InlinePositionPicker: View {
    @Binding var assignments: PositionAssignments
    @State private var showingPicker = false

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
            PositionEditorSheet(assignments: $assignments)
        }
    }
}

/// Full editor sheet for managing all position assignments
struct PositionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var assignments: PositionAssignments

    @State private var localAssignments: PositionAssignments = PositionAssignments()
    @State private var showingAddPosition = false

    private var isValid: Bool {
        localAssignments.isEmpty || localAssignments.totalPercentage == 100
    }

    var body: some View {
        NavigationStack {
            List {
                if !localAssignments.isEmpty {
                    Section {
                        ForEach(Array(localAssignments.assignments.enumerated()), id: \.element.id) { index, assignment in
                            HStack {
                                Image(systemName: assignment.position.iconName)
                                    .foregroundStyle(.accent)
                                    .frame(width: 24)

                                Text(assignment.position.displayName)

                                Spacer()

                                Stepper(
                                    "\(assignment.percentage)%",
                                    value: Binding(
                                        get: { assignment.percentage },
                                        set: { newValue in
                                            localAssignments.updatePercentage(for: assignment.position, to: newValue)
                                        }
                                    ),
                                    in: 5...100,
                                    step: 5
                                )
                                .fixedSize()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    localAssignments.removePosition(assignment.position)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Positions")
                    } footer: {
                        if !isValid && !localAssignments.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Total must equal 100% (currently \(localAssignments.totalPercentage)%)")
                            }
                            .font(.caption)
                        }
                    }
                }

                Section {
                    Button {
                        showingAddPosition = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Position")
                        }
                    }

                    if localAssignments.assignments.count > 1 {
                        Button {
                            localAssignments.normalize()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Balance to 100%")
                            }
                        }
                    }
                }

                if localAssignments.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Position", systemImage: "figure.run")
                        } description: {
                            Text("Add a position to define where this player plays")
                        }
                    }
                }
            }
            .navigationTitle("Edit Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        assignments = localAssignments
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                localAssignments = assignments
            }
            .sheet(isPresented: $showingAddPosition) {
                PositionSelectionSheet(assignments: $localAssignments)
            }
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
            PositionAssignment(position: .goalkeeper, percentage: 50)
        ])

        var body: some View {
            Form {
                InlinePositionPicker(assignments: $assignments)
            }
        }
    }

    return PreviewWrapper()
}
