import SwiftUI

struct iCloudSyncStatusCard: View {
    let syncManager: SyncManager

    var body: some View {
        let status = syncManager.status
        HStack(alignment: .top, spacing: 12) {
            if status.isActive {
                ProgressView()
                    .padding(.top, 4)
            } else {
                Image(systemName: status.needsAttention ? "exclamationmark.icloud" : "icloud")
                    .font(.title2)
                    .foregroundStyle(status.needsAttention ? Color.orange : Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(status.headline)
                    .font(.headline)
                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let date = syncManager.activity.lastTransferDate {
                    Text("Last iCloud activity: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
