import Foundation
import CloudKit

enum CloudKitErrorFormatter {
    static func userFacingMessage(for error: Error) -> String {
        let parts = uniquePreservingOrder(flatten(error))
        if parts.isEmpty {
            return fallbackMessage(for: error)
        }
        return parts.joined(separator: " ")
    }

    static func flatten(_ error: Error) -> [String] {
        let nsError = error as NSError
        var messages: [String] = []

        if let partial = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for nested in partial.values {
                messages.append(contentsOf: flatten(nested))
            }
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            messages.append(contentsOf: flatten(underlying))
        }

        if let detailed = nsError.userInfo[NSDetailedErrorsKey] as? [Error] {
            for nested in detailed {
                messages.append(contentsOf: flatten(nested))
            }
        }

        if !messages.isEmpty, isPartialFailure(nsError) {
            return messages
        }

        if let ckError = error as? CKError {
            if let described = describe(code: ckError.code.rawValue, fallback: ckError.localizedDescription) {
                messages.append(described)
            }
        } else if nsError.domain == CKError.errorDomain {
            if let described = describe(code: nsError.code, fallback: nsError.localizedDescription) {
                messages.append(described)
            }
        } else if messages.isEmpty {
            let description = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty {
                messages.append(description)
            }
        }

        return messages
    }

    private static func isPartialFailure(_ error: NSError) -> Bool {
        error.domain == CKError.errorDomain && error.code == CKError.Code.partialFailure.rawValue
    }

    private static func describe(code: Int, fallback: String) -> String? {
        switch CKError.Code(rawValue: code) {
        case .partialFailure:
            if fallback.contains("CKErrorDomain") {
                return "Some records could not be uploaded to iCloud. Player photos are now resized automatically; open Settings and tap Try Sync Again."
            }
            return nil
        case .networkUnavailable, .networkFailure:
            return "iCloud is unreachable. Check the network and try again."
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "iCloud is busy. Stattie will retry automatically."
        case .notAuthenticated:
            return "Sign in to iCloud in Settings to sync."
        case .quotaExceeded:
            return "This iCloud account is out of storage."
        case .limitExceeded:
            return "A record is too large for iCloud, usually an uncompressed photo."
        case .unknownItem, .invalidArguments, .serverRejectedRequest:
            return "iCloud rejected a record. If this continues after a retry, the production CloudKit schema may need to be deployed."
        case .serverRecordChanged:
            return "iCloud hit a record conflict and will retry."
        case .zoneNotFound, .userDeletedZone:
            return "The iCloud zone is missing. Sign out of iCloud and back in, then retry."
        case .changeTokenExpired:
            return "The iCloud change token expired. Stattie will rebuild the sync snapshot."
        default:
            let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private static func fallbackMessage(for error: Error) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty
            ? "iCloud sync failed."
            : description
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
