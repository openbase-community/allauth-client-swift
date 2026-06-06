import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - MFA - TOTP

    public func getTOTPAuthenticator() async throws -> JSON {
        return try await request(method: "GET", url: urls.totpAuthenticator)
    }

    public func activateTOTP(code: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.totpAuthenticator,
            data: ["code": code]
        )
    }

    public func deactivateTOTP() async throws -> JSON {
        return try await request(method: "DELETE", url: urls.totpAuthenticator)
    }

    public func authenticateTOTP(code: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.mfaAuthenticate,
            data: ["code": code]
        )
    }

    public func reauthenticateTOTP(code: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.mfaReauthenticate,
            data: ["code": code]
        )
    }

    // MARK: - MFA - Recovery Codes

    public func getRecoveryCodes() async throws -> JSON {
        return try await request(method: "GET", url: urls.recoveryCodesAuthenticator)
    }

    public func generateRecoveryCodes() async throws -> JSON {
        return try await request(method: "POST", url: urls.recoveryCodesAuthenticator)
    }

    public func authenticateWithRecoveryCode(code: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.mfaAuthenticate,
            data: ["code": code]
        )
    }

    public func reauthenticateWithRecoveryCode(code: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.mfaReauthenticate,
            data: ["code": code]
        )
    }

    // MARK: - MFA - WebAuthn

    public func getWebAuthnAuthenticators() async throws -> JSON {
        return try await request(method: "GET", url: urls.webauthnAuthenticator)
    }

    public func addWebAuthnAuthenticator(name: String, credential: [String: Any]) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.webauthnAuthenticator,
            data: ["name": name, "credential": credential]
        )
    }

    public func updateWebAuthnAuthenticator(id: String, name: String) async throws -> JSON {
        return try await request(
            method: "PUT",
            url: urls.webauthnAuthenticator,
            data: ["id": id, "name": name]
        )
    }

    public func deleteWebAuthnAuthenticators(ids: [String]) async throws -> JSON {
        return try await request(
            method: "DELETE",
            url: urls.webauthnAuthenticator,
            data: ["authenticators": ids]
        )
    }

    public func getWebAuthnAuthenticateOptions() async throws -> JSON {
        return try await request(method: "GET", url: urls.webauthnAuthenticate)
    }

    public func authenticateWebAuthn(credential: [String: Any]) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.webauthnAuthenticate,
            data: ["credential": credential]
        )
    }

    public func getWebAuthnReauthenticateOptions() async throws -> JSON {
        return try await request(method: "GET", url: urls.webauthnReauthenticate)
    }

    public func reauthenticateWebAuthn(credential: [String: Any]) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.webauthnReauthenticate,
            data: ["credential": credential]
        )
    }

    public func getWebAuthnLoginOptions() async throws -> JSON {
        return try await request(method: "GET", url: urls.webauthnLogin)
    }

    public func loginWebAuthn(credential: [String: Any]) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.webauthnLogin,
            data: ["credential": credential]
        )
    }

    public func getWebAuthnSignupOptions() async throws -> JSON {
        return try await request(method: "GET", url: urls.webauthnSignup)
    }

    public func signupWebAuthn(name: String, credential: [String: Any]) async throws -> JSON {
        return try await request(
            method: "PUT",
            url: urls.webauthnSignup,
            data: ["name": name, "credential": credential]
        )
    }

    public func getPasswordlessWebAuthnOptions() async throws -> JSON {
        return try await request(
            method: "GET",
            url: "\(urls.webauthnAuthenticator)?passwordless"
        )
    }

    // MARK: - MFA - Trust

    public func trustDevice() async throws -> JSON {
        return try await request(method: "POST", url: urls.mfaTrust)
    }

    // MARK: - Authenticators List

    public func getAuthenticators() async throws -> JSON {
        return try await request(method: "GET", url: urls.authenticators)
    }
}
