import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    /// Refresh the JWT access token using the refresh token
    public func refreshJWT() async throws -> JSON {
        if let existingTask = jwtRefreshTask {
            AuthDiagnostics.log("AllAuthClient", "joining in-flight JWT refresh")
            try await existingTask.value
            if let response = lastJWTRefreshResponse {
                return response
            }
            throw AllAuthError.invalidResponse
        }

        let task = Task { @MainActor in
            self.lastJWTRefreshResponse = try await self.performJWTRefresh()
        }
        jwtRefreshTask = task

        do {
            try await task.value
            let result = lastJWTRefreshResponse
            jwtRefreshTask = nil
            guard let result else {
                throw AllAuthError.invalidResponse
            }
            return result
        } catch {
            jwtRefreshTask = nil
            throw error
        }
    }

    func performJWTRefresh() async throws -> JSON {
        guard let refreshToken = jwtRefreshToken else {
            AuthDiagnostics.log("AllAuthClient", "JWT refresh requested without refresh token")
            throw AllAuthError.apiError("No refresh token available")
        }
        AuthDiagnostics.log(
            "AllAuthClient",
            "JWT refresh requested",
            metadata: ["refresh_token": AuthDiagnostics.tokenSummary(refreshToken)]
        )
        let result = try await request(
            method: "POST",
            url: urls.tokenRefresh,
            data: ["refresh_token": refreshToken],
            autoRefreshJWT: false
        )
        if jwtAccessToken == nil {
            expireSessionLocally()
            throw AllAuthError.sessionExpired
        }
        return result
    }
}
