import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - HTTP Request Handler

    public func request(
        method: String,
        url: String,
        data: [String: Any]? = nil,
        headers: [String: String] = [:],
        autoRefreshJWT: Bool = true
    ) async throws -> JSON {
        guard let requestUrl = URL(string: url) else {
            throw AllAuthError.invalidURL
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = method

        let accessToken = jwtAccessToken
        let currentSessionToken = sessionToken

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("django-allauth-swift-app", forHTTPHeaderField: "User-Agent")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else if let token = currentSessionToken {
            request.setValue(token, forHTTPHeaderField: "X-Session-Token")
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let data = data, method != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        }

        AuthDiagnostics.log(
            "AllAuthClient",
            "request",
            metadata: [
                "method": method,
                "url": AuthDiagnostics.endpointSummary(url),
                "auth": AuthDiagnostics.authHeaderSummary(accessToken: accessToken, sessionToken: currentSessionToken),
                "body": AuthDiagnostics.bodySummary(data),
                "auto_refresh_jwt": "\(autoRefreshJWT)",
            ]
        )

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AllAuthError.invalidResponse
        }

        let isTokenRefreshRequest = url == urls.tokenRefresh
        AuthDiagnostics.log(
            "AllAuthClient",
            "response",
            metadata: [
                "method": method,
                "url": AuthDiagnostics.endpointSummary(url),
                "status": "\(httpResponse.statusCode)",
            ]
        )

        if isTokenRefreshRequest, !(200 ... 299).contains(httpResponse.statusCode) {
            AuthDiagnostics.log(
                "AllAuthClient",
                "token refresh failed",
                metadata: [
                    "status": "\(httpResponse.statusCode)",
                    "body": AuthDiagnostics.redactSensitiveText(String(data: responseData, encoding: .utf8) ?? "<non-utf8>"),
                ]
            )
            if [400, 401, 410].contains(httpResponse.statusCode) {
                // allauth rejects a rotated/expired refresh token with 400.
                // Drop the dead JWT pair but keep the session token so the
                // app can attempt session-based recovery before forcing a
                // full re-login.
                clearJWTTokens()
                throw AllAuthError.sessionExpired
            }
            throw AllAuthError.apiError(
                "JWT refresh failed with status \(httpResponse.statusCode)"
            )
        }

        if httpResponse.statusCode == 401 && autoRefreshJWT && jwtRefreshToken != nil {
            AuthDiagnostics.log(
                "AllAuthClient",
                "request returned 401; refreshing JWT and retrying once",
                metadata: ["url": AuthDiagnostics.endpointSummary(url)]
            )
            _ = try await refreshJWT()
            return try await self.request(method: method, url: url, data: data, headers: headers, autoRefreshJWT: false)
        }

        let json = try JSON(data: responseData)
        AuthDiagnostics.log(
            "AllAuthClient",
            "decoded response",
            metadata: [
                "url": AuthDiagnostics.endpointSummary(url),
                "summary": AuthDiagnostics.responseSummary(json),
            ]
        )

        storeTokens(from: json)
        logTokenRefreshResultIfNeeded(json: json, responseData: responseData, statusCode: httpResponse.statusCode, isTokenRefreshRequest: isTokenRefreshRequest)

        if httpResponse.statusCode == 410 {
            AuthDiagnostics.log(
                "AllAuthClient",
                "server reported expired session",
                metadata: ["url": AuthDiagnostics.endpointSummary(url)]
            )
            sessionToken = nil
            clearJWTTokens()
            throw AllAuthError.sessionExpired
        }

        if json["meta"]["is_authenticated"].exists() {
            await handleAuthChange(json: json, previousAuth: lastAuthResponse)
            lastAuthResponse = json
        }

        return json
    }

    func storeTokens(from json: JSON) {
        if let newToken = json["meta"]["session_token"].string {
            sessionToken = newToken
        }

        if let accessToken = json["data"]["access_token"].string ?? json["meta"]["access_token"].string {
            jwtAccessToken = accessToken
        }
        if let refreshToken = json["data"]["refresh_token"].string ?? json["meta"]["refresh_token"].string {
            jwtRefreshToken = refreshToken
        }
    }

    func logTokenRefreshResultIfNeeded(
        json: JSON,
        responseData: Data,
        statusCode: Int,
        isTokenRefreshRequest: Bool
    ) {
        guard isTokenRefreshRequest else {
            return
        }

        let hasAccessToken = (json["data"]["access_token"].string ?? json["meta"]["access_token"].string) != nil
        let hasRefreshToken = (json["data"]["refresh_token"].string ?? json["meta"]["refresh_token"].string) != nil
        let errorCount = json["errors"].arrayValue.count
        AuthDiagnostics.log(
            "AllAuthClient",
            "token refresh completed",
            metadata: [
                "status": "\(statusCode)",
                "has_access_token": "\(hasAccessToken)",
                "has_refresh_token": "\(hasRefreshToken)",
                "error_count": "\(errorCount)",
            ]
        )
        if !hasAccessToken {
            AuthDiagnostics.log(
                "AllAuthClient",
                "token refresh response did not include access token",
                metadata: ["body": AuthDiagnostics.redactSensitiveText(String(data: responseData, encoding: .utf8) ?? "<non-utf8>")]
            )
        }
    }

    func handleAuthChange(json: JSON, previousAuth: JSON?) async {
        guard json["meta"]["is_authenticated"].exists() else {
            return
        }

        guard let event = AuthChangeEvent.detect(previous: previousAuth, current: json) else {
            return
        }

        lastAuthChange = event
        AuthDiagnostics.log("AllAuthClient", "auth state changed", metadata: ["event": "\(event)"])
    }
}
