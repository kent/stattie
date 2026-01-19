import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var syncManager = SyncManager.shared

    @State private var isEditingName = false
    @State private var editedName = ""

    private var currentUser: User? {
        users.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    if let user = currentUser {
                        if isEditingName {
                            HStack {
                                TextField("Display Name", text: $editedName)
                                    .textContentType(.name)

                                Button("Save") {
                                    saveDisplayName()
                                }
                                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        } else {
                            HStack {
                                Text("Display Name")
                                Spacer()
                                Text(user.displayName)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editedName = user.displayName
                                isEditingName = true
                            }
                        }

                        LabeledContent("Member Since") {
                            Text(user.createdAt, style: .date)
                        }
                    }
                }

                Section {
                    HStack {
                        Label("iCloud Status", systemImage: "icloud")
                        Spacer()
                        if syncManager.isCheckingStatus {
                            ProgressView()
                        } else {
                            Text(syncManager.statusDescription)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if syncManager.isSignedIntoiCloud {
                        if let lastSync = syncManager.lastSyncDate {
                            LabeledContent("Last Sync") {
                                Text(lastSync, style: .relative)
                            }
                        }
                    } else {
                        Text("Sign in to iCloud in Settings to sync data across devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Your data is stored locally and optionally synced via iCloud")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")

                    Link(destination: URL(string: "https://stattie.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: "https://stattie.app/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }

                Section {
                    Link(destination: URL(string: "mailto:support@stattie.app")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "https://apps.apple.com/app/stattie/id0")!) {
                        Label("Rate on App Store", systemImage: "star")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await syncManager.checkiCloudStatus()
            }
        }
    }

    private func saveDisplayName() {
        guard let user = currentUser else { return }
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        user.displayName = trimmed
        try? modelContext.save()
        isEditingName = false
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: User.self, inMemory: true)
}
