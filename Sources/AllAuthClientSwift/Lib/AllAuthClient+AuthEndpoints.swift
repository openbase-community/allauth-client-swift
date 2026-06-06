import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - Meta Endpoints

    public func getConfig() async throws -> JSON {
        return try await request(method: "GET", url: urls.config)
    }

    // MARK: - Auth Endpoints

    public func getAuth() async throws -> JSON {
        return try await request(method: "GET", url: urls.session)
    }

    public func login(email: String, password: String) async throws -> JSON {
        AuthDiagnostics.log("AllAuthClient", "login requested", metadata: ["identifier": "email"])
        return try await request(
            method: "POST",
            url: urls.login,
            data: ["email": email, "password": password]
        )
    }

    public func login(username: String, password: String) async throws -> JSON {
        AuthDiagnostics.log("AllAuthClient", "login requested", metadata: ["identifier": "username"])
        return try await request(
            method: "POST",
            url: urls.login,
            data: ["username": username, "password": password]
        )
    }

    public func logout() async throws -> JSON {
        AuthDiagnostics.log("AllAuthClient", "logout requested")
        do {
            let result = try await request(
                method: "DELETE",
                url: urls.session,
                autoRefreshJWT: false
            )
            AuthDiagnostics.log("AllAuthClient", "logout server request completed; clearing local auth state")
            expireSessionLocally()
            return result
        } catch {
            AuthDiagnostics.log(
                "AllAuthClient",
                "logout server request failed; clearing local auth state",
                metadata: ["error": "\(error)"]
            )
            expireSessionLocally()
            return JSON([
                "status": 200,
                "meta": ["is_authenticated": false],
                "data": [:],
            ])
        }
    }

    public func signUp(email: String, password: String, username: String? = nil) async throws -> JSON {
        var data: [String: Any] = [
            "email": email,
            "password": password
        ]
        if let username = username {
            data["username"] = username
        }
        return try await request(method: "POST", url: urls.signup, data: data)
    }

    public func reauthenticate(password: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.reauthenticate,
            data: ["password": password]
        )
    }

    // MARK: - Login by Code (Passwordless)

    public func requestLoginCode(email: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.requestLoginCode,
            data: ["email": email]
        )
    }

    public func confirmLoginCode(code: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.confirmLoginCode,
            data: ["code": code]
        )
    }

    // MARK: - Password Reset

    public func requestPasswordReset(email: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.requestPasswordReset,
            data: ["email": email]
        )
    }

    public func getPasswordReset(key: String) async throws -> JSON {
        return try await request(
            method: "GET",
            url: urls.resetPassword,
            headers: ["X-Password-Reset-Key": key]
        )
    }

    public func resetPassword(key: String, password: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.resetPassword,
            data: ["key": key, "password": password]
        )
    }

    // MARK: - Email Verification

    public func getEmailVerification(key: String) async throws -> JSON {
        return try await request(
            method: "GET",
            url: urls.verifyEmail,
            headers: ["X-Email-Verification-Key": key]
        )
    }

    public func verifyEmail(key: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.verifyEmail,
            data: ["key": key]
        )
    }
}
