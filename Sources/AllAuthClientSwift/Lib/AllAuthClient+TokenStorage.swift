import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - Session Token Management

    public var sessionToken: String? {
        get {
            UserDefaults.standard.string(forKey: sessionTokenKey)
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: sessionTokenKey)
                AuthDiagnostics.log(
                    "AllAuthClient",
                    "stored session token",
                    metadata: ["token": AuthDiagnostics.tokenSummary(token)]
                )
            } else {
                UserDefaults.standard.removeObject(forKey: sessionTokenKey)
                AuthDiagnostics.log("AllAuthClient", "cleared session token")
            }
        }
    }

    // MARK: - JWT Token Management

    /// JWT access token (short-lived, stored in memory only)
    public var jwtAccessToken: String? {
        get { _jwtAccessToken }
        set {
            _jwtAccessToken = newValue
            AuthDiagnostics.log(
                "AllAuthClient",
                newValue == nil ? "cleared JWT access token" : "stored JWT access token in memory",
                metadata: ["token": AuthDiagnostics.tokenSummary(newValue)]
            )
        }
    }

    /// JWT refresh token (long-lived, stored in Keychain)
    public var jwtRefreshToken: String? {
        get { KeychainHelper.read(key: jwtRefreshTokenKey) }
        set {
            if let token = newValue {
                try? KeychainHelper.save(key: jwtRefreshTokenKey, value: token)
                AuthDiagnostics.log(
                    "AllAuthClient",
                    "stored JWT refresh token in Keychain",
                    metadata: ["token": AuthDiagnostics.tokenSummary(token)]
                )
            } else {
                KeychainHelper.delete(key: jwtRefreshTokenKey)
                AuthDiagnostics.log("AllAuthClient", "cleared JWT refresh token")
            }
        }
    }

    /// Clear all JWT tokens
    public func clearJWTTokens() {
        AuthDiagnostics.log("AllAuthClient", "clearing JWT tokens")
        jwtAccessToken = nil
        jwtRefreshToken = nil
    }

    /// Clear local auth state when stored credentials can no longer refresh.
    public func expireSessionLocally() {
        AuthDiagnostics.log("AllAuthClient", "expiring session locally")
        sessionToken = nil
        clearJWTTokens()
        lastAuthResponse = JSON([
            "status": 401,
            "meta": ["is_authenticated": false],
            "data": [:],
        ])
        lastAuthChange = .loggedOut
    }
}
