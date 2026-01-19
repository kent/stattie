import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PlayerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Player

    @State private var isEditing = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showShareSheet = false
    @State private var showManageSharing = false
    @State private var isShared = false
    @State private var isOwner = true

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let photoData = player.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 120, height: 120)

                                VStack {
                                    Image(systemName: "camera")
                                        .font(.title)
                                    Text("Add Photo")
                                        .font(.caption)
                                }
                                .foregroundStyle(.accent)
                            }
                        }
                    }
                    .disabled(!isEditing)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Player Info") {
                if isEditing {
                    TextField("First Name", text: $player.firstName)
                    TextField("Last Name", text: $player.lastName)
                    HStack {
                        Text("Jersey Number")
                        Spacer()
                        TextField("", value: $player.jerseyNumber, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    TextField("Position", text: $player.position)
                } else {
                    LabeledContent("Name", value: player.fullName)
                    LabeledContent("Jersey", value: "#\(player.jerseyNumber)")
                    if !player.position.isEmpty {
                        LabeledContent("Position", value: player.position)
                    }
                }
            }

            if !isEditing {
                Section("Recent Games") {
                    if let stats = player.gameStats, !stats.isEmpty {
                        let recentStats = stats
                            .sorted { ($0.game?.gameDate ?? .distantPast) > ($1.game?.gameDate ?? .distantPast) }
                            .prefix(5)

                        ForEach(Array(recentStats)) { pgs in
                            if let game = pgs.game {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
                                            .font(.headline)
                                        Text(game.formattedDate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(game.totalPoints) pts")
                                        .font(.headline)
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                    } else {
                        Text("No games yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Menu {
                        if isShared {
                            Button {
                                showManageSharing = true
                            } label: {
                                Label("Manage Sharing...", systemImage: "person.2")
                            }
                        } else {
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share Player...", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            try? modelContext.save()
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            SharePlayerSheet(player: player)
        }
        .sheet(isPresented: $showManageSharing) {
            ShareManagementView(player: player)
        }
        .task {
            await loadShareStatus()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    player.photoData = data
                    try? modelContext.save()
                }
            }
        }
    }

    private func loadShareStatus() async {
        isShared = await player.checkIsShared()
        if isShared {
            isOwner = await player.checkIsOwner()
        }
    }
}

#Preview {
    NavigationStack {
        PlayerDetailView(player: Player(firstName: "John", lastName: "Doe", jerseyNumber: 23, position: "Guard"))
    }
    .modelContainer(for: Player.self, inMemory: true)
}
