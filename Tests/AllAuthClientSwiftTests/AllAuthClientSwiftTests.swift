import Testing
import SwiftyJSON
@testable import AllAuthClientSwift

@Test @MainActor func clientExists() async throws {
    let client: AllAuthClient? = AllAuthClient.shared
    #expect(client != nil)
}

@Test func detectsLogin() {
    let previous = JSON(["status": 401, "meta": ["is_authenticated": false]])
    let current = JSON(["status": 200, "meta": ["is_authenticated": true]])
    #expect(AuthChangeEvent.detect(previous: previous, current: current) == .loggedIn)
}

@Test func detectsLogout() {
    let previous = JSON(["status": 200, "meta": ["is_authenticated": true]])
    let current = JSON(["status": 401, "meta": ["is_authenticated": false]])
    #expect(AuthChangeEvent.detect(previous: previous, current: current) == .loggedOut)
}

@Test func detectsReauthenticationRequired() {
    let current = JSON([
        "status": 401,
        "meta": ["is_authenticated": true],
        "data": ["flows": [["id": "reauthenticate"]]],
    ])
    #expect(current.requiresReauthentication)
    #expect(AuthChangeEvent.detect(previous: current, current: current) == .reauthenticationRequired)
}

@Test func redactsSensitiveText() {
    let text = "{\"access_token\": \"abc123\", \"status\": 200, \"password\": \"hunter2\"}"
    let redacted = AuthDiagnostics.redactSensitiveText(text)
    #expect(!redacted.contains("abc123"))
    #expect(!redacted.contains("hunter2"))
    #expect(redacted.contains("<redacted>"))
    #expect(redacted.contains("\"status\": 200"))
}

@Test func endpointSummaryRedactsSensitiveQueryValues() {
    let summary = AuthDiagnostics.endpointSummary(
        "https://example.com/_allauth/app/v1/auth/session?session_token=abc123&passwordless"
    )
    #expect(!summary.contains("abc123"))
    #expect(summary.contains("passwordless"))
}
