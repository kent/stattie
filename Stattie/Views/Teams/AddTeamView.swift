import SwiftUI
import SwiftData

struct AddTeamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var users: [User]
    @Query private var sports: [Sport]

    @State private var teamName = ""
    @State private var selectedSport: Sport?
    @State private var selectedIcon = "sportscourt"
    @State private var selectedColorHex = "EA580C"  // Orange

    private var currentUser: User? {
        users.first
    }

    private var isValid: Bool {
        !teamName.trimmingCharacters(in: .whitespaces).isEmpty && selectedSport != nil
    }

    private let iconOptions = [
        "sportscourt", "basketball.fill", "soccerball", "figure.basketball",
        "figure.run", "trophy.fill", "star.fill", "bolt.fill"
    ]

    private let colorOptions = [
        ("Orange", "EA580C"),
        ("Blue", "2563EB"),
        ("Green", "16A34A"),
        ("Purple", "9333EA"),
        ("Red", "DC2626"),
        ("Teal", "0D9488"),
        ("Indigo", "4F46E5"),
        ("Pink", "DB2777")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Team Info") {
                    TextField("Team Name", text: $teamName)
                        .autocorrectionDisabled()

                    Picker("Sport", selection: $selectedSport) {
                        Text("Select a sport").tag(nil as Sport?)
                        ForEach(sports) { sport in
                            HStack {
                                Image(systemName: sport.iconName)
                                Text(sport.name)
                            }
                            .tag(sport as Sport?)
                        }
                    }
                }

                Section("Team Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: selectedColorHex) : Color(.systemGray5))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Team Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colorOptions, id: \.1) { name, hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 44, height: 44)

                                    if selectedColorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.headline.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Preview
                Section("Preview") {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedColorHex))
                                .frame(width: 60, height: 60)

                            Image(systemName: selectedIcon)
                                .font(.title)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(teamName.isEmpty ? "Team Name" : teamName)
                                .font(.headline)
                                .foregroundStyle(teamName.isEmpty ? .secondary : .primary)

                            if let sport = selectedSport {
                                HStack {
                                    Image(systemName: sport.iconName)
                                        .font(.caption)
                                    Text(sport.name)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTeam()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func createTeam() {
        let team = Team(
            name: teamName.trimmingCharacters(in: .whitespaces),
            iconName: selectedIcon,
            colorHex: selectedColorHex,
            isActive: true,
            sport: selectedSport,
            owner: currentUser
        )

        modelContext.insert(team)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    AddTeamView()
        .modelContainer(for: [Team.self, Sport.self, User.self], inMemory: true)
}
