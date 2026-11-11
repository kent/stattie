import SwiftUI
import SwiftData

/// Every player's shifts in one game: review, add, edit, delete, then finalize.
struct ManageShiftsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var persistence = PersistenceController()

    @Bindable var game: Game

    @State private var editor: EditorRoute?
    @State private var detailsShift: Shift?
    @State private var pendingDeletion: Shift?
    @State private var showingFinalizeConfirmation = false
    @State private var showingFinalScore = false
    @State private var finalScore = GameScore(team: 0, opponent: 0)

    private struct EditorRoute: Identifiable {
        let id = UUID()
        let player: PersonGameStats
        let shift: Shift?
    }

    var body: some View {
        NavigationStack {
            List {
                let players = game.shiftPlayers
                if !game.isCompleted {
                    Section {
                        Text("Review and correct shifts before finalizing the game. Tap a shift to edit it on the board.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if players.isEmpty {
                    ContentUnavailableView(
                        "No Players",
                        systemImage: "person.2.slash",
                        description: Text("Add a player to this game to track shifts.")
                    )
                }
                ForEach(players) { player in
                    Section {
                        ForEach(player.orderedShifts) { shift in
                            shiftRow(shift, player: player)
                        }
                        Button {
                            editor = EditorRoute(player: player, shift: nil)
                        } label: {
                            Label("Add Shift", systemImage: "plus.circle.fill")
                        }
                        .accessibilityHint("Opens the stat board for a new shift")
                    } header: {
                        HStack {
                            Text(player.person?.displayName ?? "Player")
                            Spacer()
                            Text("\(player.formattedTotalShiftTime) • \(player.formattedTotalPlusMinus)")
                                .monospacedDigit()
                        }
                    }
                }
            }
            .persistenceAlert(persistence)
            .navigationTitle("Manage Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $detailsShift) { shift in
                ShiftEditView(shift: shift, playerName: shift.personGameStats?.person?.displayName ?? "Player")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { finalizeBar }
            .fullScreenCover(item: $editor) { route in
                ShiftBoardEditor(player: route.player, shift: route.shift)
            }
            .alert("Delete Shift?", isPresented: deletionAlertBinding, presenting: pendingDeletion) { shift in
                Button("Delete Shift", role: .destructive) { delete(shift) }
                Button("Cancel", role: .cancel) {}
            } message: { shift in
                Text("Shift \(shift.shiftNumber) and its stats will be removed from this game.")
            }
            .alert("Finalize Game?", isPresented: $showingFinalizeConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Finalize", role: .destructive) {
                    if persistence.save(modelContext, operation: { _ = try game.finalize(in: modelContext) }) {
                        dismiss()
                    }
                }
            } message: {
                Text("This will mark the game as completed.")
            }
            .sheet(isPresented: $showingFinalScore, onDismiss: {
                if game.isCompleted { dismiss() }
            }) {
                FinalScoreSheet(score: $finalScore) {
                    _ = try game.finalize(in: modelContext, teamScore: finalScore.team, opponentScore: finalScore.opponent)
                }
            }
        }
    }

    private func shiftRow(_ shift: Shift, player: PersonGameStats) -> some View {
        Button {
            editor = EditorRoute(player: player, shift: shift)
        } label: {
            HStack(spacing: 10) {
                ShiftSummaryRow(shift: shift)
                if shift.isActive {
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                editor = EditorRoute(player: player, shift: shift)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = shift
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                detailsShift = shift
            } label: {
                Label("Details", systemImage: "slider.horizontal.3")
            }
            .tint(.gray)
        }
        .contextMenu {
            Button("Edit on Board", systemImage: "square.grid.2x2") {
                editor = EditorRoute(player: player, shift: shift)
            }
            Button("Edit Details", systemImage: "slider.horizontal.3") {
                detailsShift = shift
            }
            Button("Delete Shift", systemImage: "trash", role: .destructive) {
                pendingDeletion = shift
            }
        }
        .accessibilityHint("Opens the stat board to edit this shift. Swipe for details or delete.")
    }

    @ViewBuilder
    private var finalizeBar: some View {
        if !game.isCompleted {
            Button(action: requestFinalize) {
                Text("Finalize Game")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private func requestFinalize() {
        if game.hasActiveShifts {
            finalScore = game.latestShiftScore
            showingFinalScore = true
        } else {
            showingFinalizeConfirmation = true
        }
    }

    private func delete(_ shift: Shift) {
        guard let player = shift.personGameStats else { return }
        persistence.save(modelContext, operation: { try player.deleteShift(shift, in: modelContext) })
    }
}
