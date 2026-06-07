import Foundation
import SwiftUI
import AuthenticationServices
import SwiftyJSON

/// Sign in with Apple handler
/// Provides native Apple Sign In integration
public struct AppleSignInButton: View {
    @EnvironmentObject var authContext: AuthContext

    let process: AuthProcess
    var onSuccess: ((JSON) -> Void)?
    var onError: ((Error) -> Void)?

    @State private var isLoading = false

    private let client = AllAuthClient.shared

    public init(
        process: AuthProcess = .login,
        onSuccess: ((JSON) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.process = process
        self.onSuccess = onSuccess
        self.onError = onError
    }

    public var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                handleSignInResult(result)
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(8)
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                onError?(AppleSignInError.invalidCredential)
                return
            }

            Task {
                await authenticateWithApple(token: tokenString)
            }

        case .failure(let error):
            onError?(error)
        }
    }

    private func authenticateWithApple(token: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.authenticateWithProviderToken(
                providerId: "apple",
                token: ["id_token": token],
                process: process
            )

            if result.isSuccess {
                await authContext.refreshAuth()
            }
            onSuccess?(result)
        } catch {
            onError?(error)
        }
    }
}

/// Apple Sign In errors
public enum AppleSignInError: LocalizedError {
    case invalidCredential
    case authenticationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple credential"
        case .authenticationFailed(let message):
            return message
        }
    }
}

// MARK: - Sign in with Apple Coordinator

/// Coordinator for handling Sign in with Apple in UIKit contexts
@MainActor
public class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private let client = AllAuthClient.shared
    private let process: AuthProcess
    private var continuation: CheckedContinuation<JSON, Error>?

    public init(process: AuthProcess = .login) {
        self.process = process
    }

    public func signIn() async throws -> JSON {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            continuation?.resume(throwing: AppleSignInError.invalidCredential)
            continuation = nil
            return
        }

        Task {
            do {
                let result = try await client.authenticateWithProviderToken(
                    providerId: "apple",
                    token: ["id_token": tokenString],
                    process: process
                )
                continuation?.resume(returning: result)
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Sign in")
            .font(.headline)

        AppleSignInButton()
    }
    .padding()
    .environmentObject(AuthContext.shared)
}
