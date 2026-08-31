import Foundation
import CloudKit
import CoreData

enum SyncPipelinePhase: String, CaseIterable, Codable {
    case setup
    case download
    case upload

    var title: String {
        switch self {
        case .setup: return "Connect"
        case .download: return "Download"
        case .upload: return "Upload"
        }
    }

    var symbolName: String {
        switch self {
        case .setup: return "icloud"
        case .download: return "icloud.and.arrow.down"
        case .upload: return "icloud.and.arrow.up"
        }
    }

    var activeDetail: String {
        switch self {
        case .setup: return "Connecting to iCloud"
        case .download: return "Downloading players and games"
        case .upload: return "Uploading players and games"
        }
    }

    var completedDetail: String {
        switch self {
        case .setup: return "Connected"
        case .download: return "Downloaded"
        case .upload: return "Uploaded"
        }
    }

    init?(eventType: NSPersistentCloudKitContainer.EventType) {
        switch eventType {
        case .setup:
            self = .setup
        case .import:
            self = .download
        case .export:
            self = .upload
        @unknown default:
            return nil
        }
    }
}

enum SyncPhaseStatus: Equatable {
    case waiting
    case active
    case complete
    case failed
}

struct SyncProgress: Equatable {
    var headline: String
    var detail: String
    var errorMessage: String?
    var showsRetry: Bool
    var isActive: Bool
    var overallFraction: Double
    var statuses: [SyncPipelinePhase: SyncPhaseStatus]
    var accentName: Accent

    enum Accent: Equatable {
        case secondary
        case accent
        case healthy
        case warning
    }

    func status(for phase: SyncPipelinePhase) -> SyncPhaseStatus {
        statuses[phase] ?? .waiting
    }

    static func snapshot(
        isCloudKitBacked: Bool,
        accountStatus: CKAccountStatus,
        isCheckingStatus: Bool,
        isRetryPending: Bool,
        inFlightPhases: Set<SyncPipelinePhase>,
        completedDates: [SyncPipelinePhase: Date],
        failedPhase: SyncPipelinePhase?,
        errorMessage: String?,
        lastSyncDate: Date?,
        now: Date = Date()
    ) -> SyncProgress {
        if !isCloudKitBacked {
            return SyncProgress(
                headline: "On this iPhone only",
                detail: "iCloud sync isn’t available on this device.",
                errorMessage: nil,
                showsRetry: false,
                isActive: false,
                overallFraction: 0,
                statuses: idleStatuses,
                accentName: .secondary
            )
        }

        switch accountStatus {
        case .noAccount:
            return SyncProgress(
                headline: "Sign in to iCloud",
                detail: "Sign in on this iPhone to copy players and games across devices.",
                errorMessage: nil,
                showsRetry: false,
                isActive: false,
                overallFraction: 0,
                statuses: idleStatuses,
                accentName: .secondary
            )
        case .restricted, .temporarilyUnavailable:
            return SyncProgress(
                headline: accountStatus == .restricted ? "iCloud is restricted" : "iCloud is temporarily unavailable",
                detail: "Stattie will keep saving on this iPhone and retry when iCloud is ready.",
                errorMessage: nil,
                showsRetry: false,
                isActive: false,
                overallFraction: 0,
                statuses: idleStatuses,
                accentName: .warning
            )
        case .couldNotDetermine:
            if isCheckingStatus {
                return checkingProgress(detail: "Checking your iCloud account")
            }
            return SyncProgress(
                headline: "Checking iCloud",
                detail: "We couldn’t confirm your iCloud account yet.",
                errorMessage: nil,
                showsRetry: true,
                isActive: false,
                overallFraction: 0,
                statuses: idleStatuses,
                accentName: .secondary
            )
        case .available:
            break
        @unknown default:
            break
        }

        var statuses = idleStatuses
        for phase in SyncPipelinePhase.allCases {
            if inFlightPhases.contains(phase) {
                statuses[phase] = .active
            } else if failedPhase == phase {
                statuses[phase] = .failed
            } else if completedDates[phase] != nil {
                statuses[phase] = .complete
            }
        }

        let isActive = isCheckingStatus || isRetryPending || !inFlightPhases.isEmpty
        let fraction = pipelineFraction(statuses: statuses, isActive: isActive)
        let trimmedError = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasError = trimmedError.map { !$0.isEmpty } ?? false

        if isActive {
            let activePhase = displayedActivePhase(inFlight: inFlightPhases)
            return SyncProgress(
                headline: activePhase?.activeDetail ?? "Syncing with iCloud",
                detail: hasError
                    ? (trimmedError ?? "Retrying the last iCloud operation.")
                    : "Keeping players, games, and settings in sync.",
                errorMessage: nil,
                showsRetry: false,
                isActive: true,
                overallFraction: fraction,
                statuses: statuses,
                accentName: .accent
            )
        }

        if hasError {
            let failedTitle = failedPhase?.title.lowercased() ?? "sync"
            return SyncProgress(
                headline: "Couldn’t finish \(failedTitle)",
                detail: "Your data is still saved on this iPhone.",
                errorMessage: trimmedError,
                showsRetry: true,
                isActive: false,
                overallFraction: fraction,
                statuses: statuses,
                accentName: .warning
            )
        }

        if lastSyncDate != nil || completedDates.isEmpty == false {
            let healthyStatuses = Dictionary(
                uniqueKeysWithValues: SyncPipelinePhase.allCases.map { ($0, SyncPhaseStatus.complete) }
            )
            return SyncProgress(
                headline: "iCloud is healthy",
                detail: lastSyncedDetail(lastSyncDate: lastSyncDate, completedDates: completedDates, now: now),
                errorMessage: nil,
                showsRetry: false,
                isActive: false,
                overallFraction: 1,
                statuses: healthyStatuses,
                accentName: .healthy
            )
        }

        return SyncProgress(
            headline: "Waiting for first sync",
            detail: "Stattie will copy your data to iCloud after the next save.",
            errorMessage: nil,
            showsRetry: true,
            isActive: false,
            overallFraction: 0,
            statuses: statuses,
            accentName: .accent
        )
    }

    private static var idleStatuses: [SyncPipelinePhase: SyncPhaseStatus] {
        Dictionary(uniqueKeysWithValues: SyncPipelinePhase.allCases.map { ($0, .waiting) })
    }

    private static func checkingProgress(detail: String) -> SyncProgress {
        SyncProgress(
            headline: "Checking iCloud",
            detail: detail,
            errorMessage: nil,
            showsRetry: false,
            isActive: true,
            overallFraction: 0.12,
            statuses: idleStatuses,
            accentName: .accent
        )
    }

    private static func displayedActivePhase(inFlight: Set<SyncPipelinePhase>) -> SyncPipelinePhase? {
        for phase in SyncPipelinePhase.allCases where inFlight.contains(phase) {
            return phase
        }
        return nil
    }

    private static func pipelineFraction(
        statuses: [SyncPipelinePhase: SyncPhaseStatus],
        isActive: Bool
    ) -> Double {
        let steps = SyncPipelinePhase.allCases.map { statuses[$0] ?? .waiting }
        let total = steps.reduce(0.0) { sum, status in
            switch status {
            case .complete: return sum + 1
            case .active: return sum + 0.58
            case .failed: return sum + 0.72
            case .waiting: return sum
            }
        }
        let raw = total / Double(SyncPipelinePhase.allCases.count)
        if isActive {
            return min(0.96, max(0.12, raw))
        }
        return raw
    }

    private static func lastSyncedDetail(
        lastSyncDate: Date?,
        completedDates: [SyncPipelinePhase: Date],
        now: Date
    ) -> String {
        let latest = ([lastSyncDate] + completedDates.values.map { Optional($0) })
            .compactMap { $0 }
            .max()
        guard let latest else {
            return "Players and games are ready to copy to iCloud."
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: latest, relativeTo: now)
        if let lastPhase = latestCompletedPhase(in: completedDates) {
            return "\(lastPhase.completedDetail) \(relative)."
        }
        return "Last synced \(relative)."
    }

    private static func latestCompletedPhase(in dates: [SyncPipelinePhase: Date]) -> SyncPipelinePhase? {
        dates.max { lhs, rhs in lhs.value < rhs.value }?.key
    }
}
