import SwiftUI
import SwiftData

@MainActor
@Observable
final class PersistenceController {
    var errorMessage: String?

    /// Returns true only after the transaction commits. Callers can then dismiss.
    @discardableResult
    func save(_ context: ModelContext, operation: (() throws -> Void)? = nil) -> Bool {
        do {
            if let operation {
                try operation()
            } else {
                try context.save()
            }
            errorMessage = nil
            return true
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
            return false
        }
    }
}

extension View {
    func persistenceAlert(_ controller: PersistenceController) -> some View {
        errorAlert(message: Binding(
            get: { controller.errorMessage },
            set: { controller.errorMessage = $0 }
        ))
    }

    func errorAlert(title: String = "Couldn’t Save", message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "The change could not be saved. Please try again.")
        }
    }
}
