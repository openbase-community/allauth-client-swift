import Foundation

enum EmailVerificationDeepLink {
    enum Completion: Equatable {
        case ignored
        case authenticated
        case stillPending
        case failed
    }

    static func key(from url: URL) -> String? {
        guard url.scheme?.isEmpty == false,
              url.host?.lowercased() == "auth",
              url.path == "/verify-email",
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.fragment == nil,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              queryItems.count == 1,
              queryItems[0].name == "key",
              let key = queryItems[0].value
        else {
            return nil
        }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == key, trimmed.count <= 4_096 else {
            return nil
        }
        return trimmed
    }

    /// Completes an emailed verification handoff from the stable auth root.
    ///
    /// The URL can arrive while SwiftUI is rebuilding the pending-flow leaf,
    /// so leaf views must not own this lifecycle event. Closure injection keeps
    /// the state transition directly testable without a network dependency.
    @MainActor
    static func complete(
        url: URL,
        verify: (String) async throws -> Void,
        refreshAuth: () async -> Void,
        isAuthenticated: () -> Bool
    ) async -> Completion {
        guard let key = key(from: url) else { return .ignored }

        do {
            try await verify(key)
            await refreshAuth()
            return isAuthenticated() ? .authenticated : .stillPending
        } catch {
            return .failed
        }
    }
}
