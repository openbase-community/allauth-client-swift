import Foundation
import SwiftUI
import AuthenticationServices
import SwiftyJSON

/// Sign in with Apple handler
/// Provides native Apple Sign In integration
struct AppleSignInButton: View {
    @EnvironmentObject var authContext: AuthContext

    let process: AuthProcess
    var onSuccess: ((JSON) -> Void)?
    var onError: ((Error) -> Void)?

    @State private var isLoading = false

    private let client = AllAuthClient.shared

    init(
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
                await authenticateWithApple(token: tokenString, credential: appleIDCredential)
            }

        case .failure(let error):
            onError?(error)
        }
    }

    private func authenticateWithApple(token: String, credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.authenticateWithProviderToken(
                providerId: "apple",
                token: token,
                process: process
            )

            if result.isSuccess {
                await authContext.refreshAuth()
                onSuccess?(result)
            } else {
                onError?(AppleSignInError.authenticationFailed(result.firstGeneralError ?? "Unknown error"))
            }
        } catch {
            onError?(error)
        }
    }
}

/// Apple Sign In errors
enum AppleSignInError: LocalizedError {
    case invalidCredential
    case authenticationFailed(String)

    var errorDescription: String? {
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
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private let client = AllAuthClient.shared
    private let process: AuthProcess
    private var continuation: CheckedContinuation<JSON, Error>?

    init(process: AuthProcess = .login) {
        self.process = process
    }

    func signIn() async throws -> JSON {
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

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
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
                    token: tokenString,
                    process: process
                )
                continuation?.resume(returning: result)
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window available")
        }
        return window
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
