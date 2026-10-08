import Foundation
import SwiftyJSON
import Testing
@testable import AllAuthClientSwift

// MARK: - Submission

@Suite @MainActor struct LoginCodeConfirmationTests {
    /// Records what the screen would send and answers with a canned response.
    @MainActor final class Recorder {
        var sentCodes: [String] = []
        var reply: Result<JSON, Error>

        init(_ reply: JSON) {
            self.reply = .success(reply)
        }

        init(error: Error) {
            reply = .failure(error)
        }

        var confirmation: LoginCodeConfirmation {
            LoginCodeConfirmation { [self] code in
                sentCodes.append(code)
                return try reply.get()
            }
        }
    }

    static let signedIn = JSON([
        "status": 200,
        "meta": ["is_authenticated": true],
        "data": ["user": ["id": 1]],
    ])

    @Test func sendsTheNormalizedCode() async {
        let recorder = Recorder(Self.signedIn)

        let result = await recorder.confirmation.submit(code: " 99gj-qg \n")

        #expect(recorder.sentCodes == ["99GJQG"])
        #expect(result.outcome == .signedIn)
    }

    @Test func emptyCodeShowsAnErrorInsteadOfDoingNothing() async {
        let recorder = Recorder(Self.signedIn)

        let result = await recorder.confirmation.submit(code: "  - ")

        #expect(recorder.sentCodes.isEmpty)
        #expect(result.outcome == .showErrors)
        #expect(result.response.error(for: "code") == LoginCodeConfirmation.emptyCodeMessage)
    }

    /// allauth answers 409 with no message once the pending login-code stage
    /// is gone (the code expires after 3 minutes). That used to be silent.
    @Test func expiredFlowRestartsWithAVisibleMessage() async {
        let recorder = Recorder(JSON(["status": 409]))

        let result = await recorder.confirmation.submit(code: "99GJQG")

        #expect(recorder.sentCodes == ["99GJQG"])
        #expect(result.outcome == .restartFlow)
        #expect(result.response.generalErrors == [LoginCodeConfirmation.expiredMessage])
    }

    @Test func wrongCodeShowsTheServerError() async {
        let recorder = Recorder(JSON([
            "status": 400,
            "errors": [["message": "Incorrect code.", "code": "incorrect_code", "param": "code"]],
        ]))

        let result = await recorder.confirmation.submit(code: "AAAAAA")

        #expect(result.outcome == .showErrors)
        #expect(result.response.error(for: "code") == "Incorrect code.")
    }

    @Test func networkFailureShowsAnError() async {
        let recorder = Recorder(error: URLError(.notConnectedToInternet))

        let result = await recorder.confirmation.submit(code: "99GJQG")

        #expect(recorder.sentCodes == ["99GJQG"])
        #expect(result.outcome == .showErrors)
        #expect(!result.response.generalErrors.isEmpty)
    }

    @Test func pendingNextStepLeavesTheCodeScreen() async {
        let recorder = Recorder(JSON([
            "status": 401,
            "meta": ["is_authenticated": false],
            "data": ["flows": [
                ["id": "login_by_code"],
                ["id": "mfa_authenticate", "is_pending": true],
            ]],
        ]))

        let result = await recorder.confirmation.submit(code: "99GJQG")

        #expect(result.outcome == .nextStep)
    }

    @Test func responsesWithoutAMessageStillShowOne() async {
        let unexplained = [
            JSON(["status": 401, "meta": ["is_authenticated": false], "data": ["flows": [["id": "login_by_code", "is_pending": true]]]]),
            JSON(["status": 500]),
            JSON(["status": 400, "errors": [["message": "Bad email.", "param": "email"]]]),
        ]

        for reply in unexplained {
            let result = await Recorder(reply).confirmation.submit(code: "99GJQG")

            #expect(result.outcome == .showErrors)
            let shown = result.response.generalErrors + [result.response.error(for: "code")].compactMap { $0 }
            #expect(!shown.isEmpty, "no visible error for \(reply)")
        }
    }
}

// MARK: - Restart navigation

@Suite @MainActor struct LoginCodeRestartTests {
    @Test func restartReplacesTheStackWithRequestCodeAndCarriesTheNotice() {
        let manager = AuthNavigationManager(authContext: AuthContext.shared)
        manager.navigate(to: .requestLoginCode)
        manager.navigate(to: .confirmLoginCode)

        manager.restartLoginByCode(notice: LoginCodeConfirmation.expiredMessage)

        #expect(manager.path.count == 1)
        #expect(manager.currentRoute == .requestLoginCode)
        #expect(manager.loginCodeRestart?.notice == LoginCodeConfirmation.expiredMessage)
    }

    @Test func eachRestartIsDistinct() {
        let manager = AuthNavigationManager(authContext: AuthContext.shared)

        manager.restartLoginByCode(notice: nil)
        let first = manager.loginCodeRestart
        manager.restartLoginByCode(notice: nil)

        #expect(first != nil)
        #expect(manager.loginCodeRestart != first)
    }
}

// MARK: - Client transport

/// Serves canned allauth responses to `URLSession.shared` for one host.
final class StubAllAuthProtocol: URLProtocol, @unchecked Sendable {
    static let host = "allauth-stub.test"
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, [String: Any]))?
    /// Runs on the main actor after the request is received and before the
    /// response is delivered, to simulate work that races the request.
    nonisolated(unsafe) static var beforeResponse: (@MainActor () -> Void)?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset() {
        handler = nil
        beforeResponse = nil
        requests = []
    }

    static func body(of request: URLRequest) -> JSON {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                collected.append(buffer, count: count)
            }
            data = collected
        }
        return data.flatMap { try? JSON(data: $0) } ?? JSON.null
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        let (status, json) = Self.handler?(request) ?? (404, ["status": 404])
        let before = Self.beforeResponse
        let request = request
        Task { @MainActor in
            before?()
            let data = try! JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

/// These share `AllAuthClient.shared` and its stored tokens, so they run one
/// at a time and restore the client afterwards.
@Suite(.serialized) @MainActor struct AllAuthClientStubbedTransportTests {
    init() {
        URLProtocol.registerClass(StubAllAuthProtocol.self)
        StubAllAuthProtocol.reset()
        let client = AllAuthClient.shared
        client.setup(baseUrl: "https://\(StubAllAuthProtocol.host)/_allauth/app/v1")
        client.sessionToken = nil
        client.jwtAccessToken = nil
    }

    private func cleanUp() {
        StubAllAuthProtocol.reset()
        AllAuthClient.shared.sessionToken = nil
        AllAuthClient.shared.jwtAccessToken = nil
    }

    @Test func confirmScreenSendsTheNormalizedCodeWithTheFlowSessionToken() async throws {
        defer { cleanUp() }
        let client = AllAuthClient.shared
        client.sessionToken = "flow-session"
        StubAllAuthProtocol.handler = { _ in
            (200, ["status": 200, "meta": ["is_authenticated": true], "data": ["user": ["id": 1]]])
        }

        let result = await LoginCodeConfirmation { code in
            try await client.confirmLoginCode(code: code)
        }.submit(code: "99gj qg")

        let request = try #require(StubAllAuthProtocol.requests.last)
        #expect(request.url?.path == "/_allauth/app/v1/auth/code/confirm")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Session-Token") == "flow-session")
        #expect(StubAllAuthProtocol.body(of: request)["code"].string == "99GJQG")
        #expect(result.outcome == .signedIn)
    }

    @Test func expiredLoginCodeConflictIsShownAndRestarts() async throws {
        defer { cleanUp() }
        let client = AllAuthClient.shared
        client.sessionToken = "flow-session"
        StubAllAuthProtocol.handler = { _ in (409, ["status": 409]) }

        let result = await LoginCodeConfirmation { code in
            try await client.confirmLoginCode(code: code)
        }.submit(code: "99GJQG")

        #expect(StubAllAuthProtocol.requests.count == 1)
        #expect(result.outcome == .restartFlow)
        #expect(result.response.generalErrors == [LoginCodeConfirmation.expiredMessage])
    }
}
