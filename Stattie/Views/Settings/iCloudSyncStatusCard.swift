import SwiftUI

struct iCloudSyncStatusCard: View {
    @Bindable var syncManager: SyncManager

    private var progress: SyncProgress {
        syncManager.progress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            pipeline
            if progress.isActive {
                ProgressView(value: progress.overallFraction)
                    .tint(tint)
                    .animation(.easeInOut(duration: 0.35), value: progress.overallFraction)
            }
            if let errorMessage = progress.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !progress.isActive, progress.showsRetry || syncManager.isSignedIntoiCloud {
                Button {
                    Task { await syncManager.retrySync() }
                } label: {
                    Text(progress.showsRetry ? "Try Sync Again" : "Sync Now")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 44, height: 44)
                Group {
                    if progress.isActive {
                        ProgressView()
                    } else {
                        Image(systemName: headerSymbol)
                            .font(.title3)
                    }
                }
                .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(progress.headline)
                    .font(.headline)
                    .foregroundStyle(progress.accentName == .warning ? Color.orange : Color.primary)
                Text(progress.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pipeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(SyncPipelinePhase.allCases.enumerated()), id: \.element) { index, phase in
                phaseColumn(phase)
                if index < SyncPipelinePhase.allCases.count - 1 {
                    connector(from: phase, to: SyncPipelinePhase.allCases[index + 1])
                }
            }
        }
        .padding(.top, 4)
    }

    private func phaseColumn(_ phase: SyncPipelinePhase) -> some View {
        let status = progress.status(for: phase)
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(phaseFill(status))
                    .frame(width: 34, height: 34)
                Circle()
                    .stroke(phaseStroke(status), lineWidth: status == .waiting ? 1 : 0)
                    .frame(width: 34, height: 34)
                if status == .active {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)
                } else {
                    Image(systemName: phaseSymbol(status, phase: phase))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(phaseIconColor(status))
                }
            }
            Text(phase.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(status == .waiting ? Color.secondary : Color.primary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phase.title), \(accessibilityStatus(status))")
    }

    private func connector(from lhs: SyncPipelinePhase, to rhs: SyncPipelinePhase) -> some View {
        let leading = progress.status(for: lhs)
        let trailing = progress.status(for: rhs)
        let filled = isFilled(leading) && (isFilled(trailing) || trailing == .active || trailing == .failed)
        return Capsule()
            .fill(filled ? tint.opacity(0.85) : Color.secondary.opacity(0.22))
            .frame(height: 3)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
    }

    private var headerSymbol: String {
        switch progress.accentName {
        case .healthy: return "checkmark.icloud.fill"
        case .warning: return "exclamationmark.icloud.fill"
        case .accent, .secondary: return "icloud.fill"
        }
    }

    private var tint: Color {
        switch progress.accentName {
        case .healthy: return .green
        case .warning: return .orange
        case .accent: return .accentColor
        case .secondary: return .secondary
        }
    }

    private func phaseFill(_ status: SyncPhaseStatus) -> Color {
        switch status {
        case .complete: return tint.opacity(0.18)
        case .active: return Color.accentColor.opacity(0.16)
        case .failed: return Color.orange.opacity(0.16)
        case .waiting: return Color.secondary.opacity(0.08)
        }
    }

    private func phaseStroke(_ status: SyncPhaseStatus) -> Color {
        status == .waiting ? Color.secondary.opacity(0.35) : .clear
    }

    private func phaseSymbol(_ status: SyncPhaseStatus, phase: SyncPipelinePhase) -> String {
        switch status {
        case .complete: return "checkmark"
        case .failed: return "exclamationmark"
        case .waiting, .active: return phase.symbolName
        }
    }

    private func phaseIconColor(_ status: SyncPhaseStatus) -> Color {
        switch status {
        case .complete: return tint
        case .failed: return .orange
        case .active: return .accentColor
        case .waiting: return .secondary
        }
    }

    private func isFilled(_ status: SyncPhaseStatus) -> Bool {
        switch status {
        case .complete, .failed: return true
        case .waiting, .active: return false
        }
    }

    private func accessibilityStatus(_ status: SyncPhaseStatus) -> String {
        switch status {
        case .waiting: return "waiting"
        case .active: return "in progress"
        case .complete: return "complete"
        case .failed: return "failed"
        }
    }

    private var accessibilitySummary: String {
        var parts = [progress.headline, progress.detail]
        if let errorMessage = progress.errorMessage {
            parts.append(errorMessage)
        }
        return parts.joined(separator: ". ")
    }
}
