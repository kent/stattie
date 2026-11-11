import SwiftUI
import SwiftData

/// Edits one shift on the interactive stat board. Taps change a draft; nothing is
/// saved until the shift's score is confirmed.
struct ShiftBoardEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let player: PersonGameStats
    /// Nil creates a new shift for `player`.
    let shift: Shift?

    @State private var draft: ShiftEditDraft
    @State private var showingScoreConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var didSave = false

    init(player: PersonGameStats, shift: Shift? = nil) {
        self.player = player
        self.shift = shift
        _draft = State(initialValue: shift.map { ShiftEditDraft(shift: $0) } ?? ShiftEditDraft(newShiftFor: player))
    }

    private var game: Game? { player.game }
    private var sportName: String? { game?.sport?.name }
    private var playerName: String { player.person?.displayName ?? "Player" }
    private var position: SoccerPosition? { SoccerPosition(rawValue: draft.details.positionRawValue) }

    private var positions: [SoccerPosition] {
        SoccerPosition.positions(for: SoccerPosition.supportedSport(for: sportName))
    }

    private var visiblePositions: [SoccerPosition] {
        if let position { return [position] }
        return player.person?.positionAssignments(for: game).positions(for: sportName) ?? []
    }

    private var title: String {
        shift.map { "Edit Shift \($0.shiftNumber)" } ?? "New Shift"
    }

    private var durationText: String {
        guard let end = draft.details.endTime else { return "In progress" }
        let seconds = max(0, Int(end.timeIntervalSince(draft.details.startTime).rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var scoreText: String {
        let details = draft.details
        let start = "\(details.startingTeamScore)-\(details.startingOpponentScore)"
        guard details.endTime != nil else { return "Started at \(start)" }
        let end = "\(details.endingTeamScore ?? details.startingTeamScore)-\(details.endingOpponentScore ?? details.startingOpponentScore)"
        return "\(start) → \(end)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                header
                StatBoardView(
                    sport: game?.sport,
                    position: position,
                    visiblePositions: visiblePositions,
                    stats: draft,
                    contextStats: draft,
                    isShiftScoped: true,
                    record: { name, points, mutation in
                        draft.apply(mutation, named: name, pointValue: points)
                    },
                    undo: { name, mutation in
                        draft.apply(mutation, named: name, pointValue: 0, delta: -1)
                    }
                )
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if draft.hasChanges { showingDiscardConfirmation = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingScoreConfirmation = true }
                }
            }
            .confirmationDialog("Discard changes to this shift?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .sheet(isPresented: $showingScoreConfirmation, onDismiss: {
                if didSave { dismiss() }
            }) {
                ShiftScoreConfirmationSheet(details: $draft.details) {
                    if let shift {
                        try draft.save(to: shift, in: modelContext)
                    } else {
                        try draft.create(for: player, in: modelContext)
                    }
                    didSave = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(playerName)
                    .font(.headline)
                Spacer()
                if !positions.isEmpty {
                    Menu {
                        Picker("Position", selection: $draft.details.positionRawValue) {
                            Text("Unspecified").tag("")
                            ForEach(positions) { position in
                                Label(position.displayName, systemImage: position.iconName).tag(position.rawValue)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: position?.iconName ?? "figure.run")
                            Text(position?.displayName ?? "Choose position")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel("Shift position")
                    .accessibilityValue(position?.displayName ?? "None selected")
                }
            }

            HStack {
                Label(durationText, systemImage: "clock")
                Text("•")
                Text(scoreText)
                Spacer()
                NavigationLink {
                    ShiftDraftForm(draft: $draft, playerName: playerName, sportName: sportName)
                        .navigationTitle("Time & Details")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Time & details", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
