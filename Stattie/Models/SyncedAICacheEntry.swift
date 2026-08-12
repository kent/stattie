import Foundation
import SwiftData

@Model
final class SyncedAICacheEntry {
    var id: UUID = UUID()
    var cacheKey: String = ""
    var payload: Data = Data()
    var updatedAt: Date = Date()

    init(cacheKey: String, payload: Data) {
        self.id = UUID()
        self.cacheKey = cacheKey
        self.payload = payload
        self.updatedAt = Date()
    }
}
