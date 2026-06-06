import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - Sessions Management

    public func getSessions() async throws -> JSON {
        return try await request(method: "GET", url: urls.sessions)
    }

    public func deleteSessions(ids: [String]) async throws -> JSON {
        return try await request(
            method: "DELETE",
            url: urls.sessions,
            data: ["sessions": ids]
        )
    }
}
