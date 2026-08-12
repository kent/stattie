import SwiftData

enum SharedModelContainer {
    static var container: ModelContainer?
    static var isCloudKitBacked = false

    static func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }
}
