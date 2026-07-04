import Foundation
import AuthenticationServices
import SwiftUI
import SwiftyJSON

/// Performs platform passkey / security key ceremonies for the WebAuthn flows
/// exposed by django-allauth headless, translating between the server's
/// publicKey options and AuthenticationServices requests.
@MainActor
public final class WebAuthnAuthenticator: NSObject {
    public enum WebAuthnError: LocalizedError {
        case invalidOptions(String)
        case unexpectedCredential

        public var errorDescription: String? {
            switch self {
            case .invalidOptions(let detail):
                return "Invalid WebAuthn options from server: \(detail)"
            case .unexpectedCredential:
                return "Received an unexpected credential type"
            }
        }
    }

    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var controller: ASAuthorizationController?

    /// Register a new platform passkey using the creation options returned by
    /// the allauth headless API, and serialize the attestation response into
    /// the credential JSON shape the server expects.
    public func register(creationOptions: JSON) async throws -> [String: Any] {
        let publicKey = Self.publicKeyOptions(in: creationOptions, container: "creation_options")

        guard let rpId = publicKey["rp"]["id"].string else {
            throw WebAuthnError.invalidOptions("missing rp.id")
        }
        guard let challenge = Self.base64URLDecode(publicKey["challenge"].stringValue) else {
            throw WebAuthnError.invalidOptions("missing challenge")
        }
        guard let userID = Self.base64URLDecode(publicKey["user"]["id"].stringValue) else {
            throw WebAuthnError.invalidOptions("missing user.id")
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: publicKey["user"]["name"].string ?? publicKey["user"]["displayName"].stringValue,
            userID: userID
        )

        let authorization = try await performRequests([request])

        guard
            let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
            let attestationObject = credential.rawAttestationObject
        else {
            throw WebAuthnError.unexpectedCredential
        }

        let credentialId = Self.base64URLEncode(credential.credentialID)
        return [
            "id": credentialId,
            "rawId": credentialId,
            "type": "public-key",
            "authenticatorAttachment": "platform",
            "response": [
                "clientDataJSON": Self.base64URLEncode(credential.rawClientDataJSON),
                "attestationObject": Self.base64URLEncode(attestationObject),
                "transports": ["internal"],
            ],
            "clientExtensionResults": [String: Any](),
        ]
    }

    /// Authenticate with an existing passkey / security key using the request
    /// options returned by the allauth headless API, and serialize the
    /// assertion response into the credential JSON shape the server expects.
    public func authenticate(requestOptions: JSON) async throws -> [String: Any] {
        let publicKey = Self.publicKeyOptions(in: requestOptions, container: "request_options")

        guard let rpId = publicKey["rpId"].string ?? publicKey["rp"]["id"].string else {
            throw WebAuthnError.invalidOptions("missing rpId")
        }
        guard let challenge = Self.base64URLDecode(publicKey["challenge"].stringValue) else {
            throw WebAuthnError.invalidOptions("missing challenge")
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        let allowedCredentials = publicKey["allowCredentials"].arrayValue.compactMap { descriptor -> ASAuthorizationPlatformPublicKeyCredentialDescriptor? in
            guard let credentialID = Self.base64URLDecode(descriptor["id"].stringValue) else {
                return nil
            }
            return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credentialID)
        }
        if !allowedCredentials.isEmpty {
            request.allowedCredentials = allowedCredentials
        }

        let authorization = try await performRequests([request])

        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw WebAuthnError.unexpectedCredential
        }

        var response: [String: Any] = [
            "clientDataJSON": Self.base64URLEncode(credential.rawClientDataJSON),
            "authenticatorData": Self.base64URLEncode(credential.rawAuthenticatorData),
            "signature": Self.base64URLEncode(credential.signature),
        ]
        let userHandle: Data? = credential.userID
        if let userHandle, !userHandle.isEmpty {
            response["userHandle"] = Self.base64URLEncode(userHandle)
        }

        let credentialId = Self.base64URLEncode(credential.credentialID)
        return [
            "id": credentialId,
            "rawId": credentialId,
            "type": "public-key",
            "authenticatorAttachment": "platform",
            "response": response,
            "clientExtensionResults": [String: Any](),
        ]
    }

    // MARK: - Private

    /// Locate the publicKey options in a full allauth response, a bare options
    /// container, or the publicKey dictionary itself.
    private static func publicKeyOptions(in json: JSON, container: String) -> JSON {
        if json["data"][container]["publicKey"].exists() {
            return json["data"][container]["publicKey"]
        }
        if json[container]["publicKey"].exists() {
            return json[container]["publicKey"]
        }
        if json["publicKey"].exists() {
            return json["publicKey"]
        }
        return json
    }

    private func performRequests(_ requests: [ASAuthorizationRequest]) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: requests)
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        guard !value.isEmpty else { return nil }
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension WebAuthnAuthenticator: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
        self.controller = nil
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        self.controller = nil
    }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
