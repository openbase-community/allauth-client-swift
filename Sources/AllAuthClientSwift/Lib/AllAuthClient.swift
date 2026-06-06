import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - AllAuth Client

@MainActor
public class AllAuthClient: ObservableObject {
    public static let shared = AllAuthClient()

    // Settings
    public private(set) var baseUrl: String = ""
    var urls: URLs!

    // Session token storage key
    let sessionTokenKey = "allauth_session_token"

    // JWT token storage
    let jwtRefreshTokenKey = "allauth_jwt_refresh_token"
    var _jwtAccessToken: String?
    var jwtRefreshTask: Task<Void, Error>?
    var lastJWTRefreshResponse: JSON?

    // Published auth change for UI updates
    @Published public var lastAuthChange: AuthChangeEvent?
    @Published public var lastAuthResponse: JSON?

    private init() {}

    // MARK: - Setup

    public func setup(baseUrl: String) {
        self.baseUrl = baseUrl
        self.urls = URLs(baseUrl: baseUrl)
        AuthDiagnostics.log(
            "AllAuthClient",
            "configured",
            metadata: ["base_url": AuthDiagnostics.endpointSummary(baseUrl)]
        )
    }
}
