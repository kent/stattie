import SwiftUI
import SwiftData
import UIKit

struct PersonListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.jerseyNumber) private var players: [Person]
    @State private var showingAddPerson = false
    @State private var searchText = ""

    var filteredPersons: [Person] {
        if searchText.isEmpty {
            return players.filter { $0.isActive }
        }
        return players.filter { player in
            player.isActive && (
                player.firstName.localizedCaseInsensitiveContains(searchText) ||
                player.lastName.localizedCaseInsensitiveContains(searchText) ||
                "\(player.jerseyNumber)".contains(searchText)
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredPersons.isEmpty {
                    ContentUnavailableView {
                        Label("No Persons", systemImage: "person.3")
                    } description: {
                        Text("Add players to start tracking their stats")
                    } actions: {
                        Button("Add Person") {
                            showingAddPerson = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(filteredPersons) { player in
                            NavigationLink(value: player) {
                                PersonRowView(player: player)
                            }
                        }
                        .onDelete(perform: deletePerson)
                    }
                }
            }
            .navigationTitle("Persons")
            .navigationDestination(for: Person.self) { player in
                PersonDetailView(player: player)
            }
            .searchable(text: $searchText, prompt: "Search players")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPerson = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView()
            }
        }
    }

    private func deletePerson(at offsets: IndexSet) {
        for index in offsets {
            let player = filteredPersons[index]
            player.isActive = false
        }
        try? modelContext.save()
    }
}

struct PersonRowView: View {
    let player: Person

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                if let photoData = player.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text("#\(player.jerseyNumber)")
                        .font(.headline)
                        .foregroundStyle(.accent)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.fullName)
                        .font(.headline)
                    AsyncSharedPersonBadge(player: player)
                }

                if !player.position.isEmpty {
                    Text(player.position)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PersonListView()
        .modelContainer(for: Person.self, inMemory: true)
}
