import Foundation
import SwiftyJSON

extension JSON: @retroactive @unchecked Sendable {}

/// Authentication flow types
public enum AuthFlow: String, CaseIterable {
    case login = "login"
    case loginByCode = "login_by_code"
    case signup = "signup"
    case verifyEmail = "verify_email"
    case providerRedirect = "provider_redirect"
    case providerSignup = "provider_signup"
    case mfaAuthenticate = "mfa_authenticate"
    case mfaReauthenticate = "mfa_reauthenticate"
    case reauthenticate = "reauthenticate"
    case mfaTrust = "mfa_trust"
    case mfaWebAuthnSignup = "mfa_webauthn_signup"
    case passwordResetByCode = "password_reset_by_code"
}

/// Authenticator types for MFA
public enum AuthenticatorType: String {
    case totp = "totp"
    case recoveryCodes = "recovery_codes"
    case webauthn = "webauthn"
}

/// Authentication process types
public enum AuthProcess: String, Sendable {
    case login = "login"
    case connect = "connect"
}

public enum AuthChangeEvent: Equatable {
    case loggedIn
    case loggedOut
    case reauthenticated
    case reauthenticationRequired
    case flowUpdated
}

public enum AllAuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case sessionExpired
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .sessionExpired:
            return "Session expired. Please log in again."
        case .apiError(let message):
            return message
        }
    }
}

public extension JSON {
    /// Check if the response indicates success (status 200)
    var isSuccess: Bool {
        return self["status"].intValue == 200
    }

    /// Check if authentication is required
    var requiresAuth: Bool {
        return self["status"].intValue == 401
    }

    /// Check if there are pending flows
    var hasPendingFlows: Bool {
        return self["data"]["flows"].arrayValue.contains { $0["is_pending"].boolValue }
    }

    /// Get specific pending flow
    func pendingFlow(of type: AuthFlow) -> JSON? {
        return self["data"]["flows"].arrayValue.first {
            $0["id"].string == type.rawValue && $0["is_pending"].boolValue
        }
    }

    /// Get all errors
    var errors: [(param: String?, message: String)] {
        return self["errors"].arrayValue.map { error in
            (error["param"].string, error["message"].stringValue)
        }
    }

    /// Get error for specific field
    func error(for field: String) -> String? {
        return self["errors"].arrayValue.first { $0["param"].string == field }?["message"].string
    }

    /// Get general errors (not associated with a field)
    var generalErrors: [String] {
        return self["errors"].arrayValue
            .filter { $0["param"].string == nil }
            .map { $0["message"].stringValue }
    }

    /// Get user from auth response
    var user: JSON? {
        return self["data"]["user"].exists() ? self["data"]["user"] : nil
    }

    /// Check if user is authenticated
    var isAuthenticated: Bool {
        return self["meta"]["is_authenticated"].bool ?? false
    }
}
