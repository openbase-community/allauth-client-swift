import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - Social Account Providers

    public func getProviders() async throws -> JSON {
        return try await request(method: "GET", url: urls.providers)
    }

    public func disconnectProvider(providerId: String, accountUid: String) async throws -> JSON {
        return try await request(
            method: "DELETE",
            url: urls.providers,
            data: ["provider": providerId, "account": accountUid]
        )
    }

    public func authenticateWithProviderToken(
        providerId: String,
        token: [String: Any],
        process: AuthProcess = .login
    ) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.providerToken,
            data: [
                "provider": providerId,
                "token": token,
                "process": process.rawValue
            ]
        )
    }

    public func authenticateWithProviderToken(
        providerId: String,
        accessToken: String,
        process: AuthProcess = .login
    ) async throws -> JSON {
        return try await authenticateWithProviderToken(
            providerId: providerId,
            token: ["access_token": accessToken],
            process: process
        )
    }

    public func completeProviderSignup(email: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.providerSignup,
            data: ["email": email]
        )
    }
}
