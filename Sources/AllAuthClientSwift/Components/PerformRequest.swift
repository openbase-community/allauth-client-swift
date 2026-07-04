import Foundation
import SwiftUI
import SwiftyJSON

/// Runs an auth API request while toggling a loading binding, converting any
/// thrown error into an allauth-style `errors` payload that `FormErrors` can
/// render. Errors are also routed through `AuthDiagnostics`.
@MainActor
public func performRequest(
    loading isLoading: Binding<Bool>? = nil,
    context: String = "request",
    _ operation: @MainActor () async throws -> JSON
) async -> JSON {
    isLoading?.wrappedValue = true
    defer { isLoading?.wrappedValue = false }

    do {
        return try await operation()
    } catch {
        AuthDiagnostics.log("AuthView", "\(context) failed", metadata: ["error": "\(error)"])
        return JSON(["errors": [["message": error.localizedDescription]]])
    }
}
