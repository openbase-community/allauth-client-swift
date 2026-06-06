import Foundation

struct URLs {
    let baseUrl: String

    init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    // Meta
    var config: String { "\(baseUrl)/config" }

    // Account
    var changePassword: String { "\(baseUrl)/account/password/change" }
    var emailAddresses: String { "\(baseUrl)/account/email" }
    var authenticators: String { "\(baseUrl)/account/authenticators" }
    var totpAuthenticator: String { "\(baseUrl)/account/authenticators/totp" }
    var recoveryCodesAuthenticator: String { "\(baseUrl)/account/authenticators/recovery-codes" }
    var webauthnAuthenticator: String { "\(baseUrl)/account/authenticators/webauthn" }
    var providers: String { "\(baseUrl)/account/providers" }

    // Auth
    var session: String { "\(baseUrl)/auth/session" }
    var tokenRefresh: String { "\(baseUrl)/tokens/refresh" }
    var login: String { "\(baseUrl)/auth/login" }
    var reauthenticate: String { "\(baseUrl)/auth/reauthenticate" }
    var requestLoginCode: String { "\(baseUrl)/auth/code/request" }
    var confirmLoginCode: String { "\(baseUrl)/auth/code/confirm" }
    var signup: String { "\(baseUrl)/auth/signup" }
    var verifyEmail: String { "\(baseUrl)/auth/email/verify" }
    var requestPasswordReset: String { "\(baseUrl)/auth/password/request" }
    var resetPassword: String { "\(baseUrl)/auth/password/reset" }

    // MFA
    var mfaAuthenticate: String { "\(baseUrl)/auth/2fa/authenticate" }
    var mfaReauthenticate: String { "\(baseUrl)/auth/2fa/reauthenticate" }
    var mfaTrust: String { "\(baseUrl)/auth/2fa/trust" }
    var webauthnAuthenticate: String { "\(baseUrl)/auth/webauthn/authenticate" }
    var webauthnReauthenticate: String { "\(baseUrl)/auth/webauthn/reauthenticate" }
    var webauthnLogin: String { "\(baseUrl)/auth/webauthn/login" }
    var webauthnSignup: String { "\(baseUrl)/auth/webauthn/signup" }

    // Social
    var providerRedirect: String { "\(baseUrl)/auth/provider/redirect" }
    var providerToken: String { "\(baseUrl)/auth/provider/token" }
    var providerSignup: String { "\(baseUrl)/auth/provider/signup" }

    // Sessions
    var sessions: String { "\(baseUrl)/auth/sessions" }
}
