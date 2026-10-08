import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Request Login Code

/// Request login code view (passwordless login)
/// Equivalent to RequestLoginCode.js in the React implementation
public struct RequestLoginCodeView: View {
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var email = ""
    @State private var isLoading = false
    @State private var response: JSON?
    @State private var codeSent = false

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Sign In with Code",
            subtitle: "We'll send a one-time code to your email."
        ) {
            if codeSent {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Check Your Email")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("We've sent a login code to \(email)")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Path-based (not a view-destination NavigationLink) so
                    // pop and restart from the Enter Code screen behave the
                    // same however it was reached.
                    Button {
                        navigationManager.loginCodeEmail = email
                        navigationManager.navigate(to: .confirmLoginCode)
                    } label: {
                        Text("Enter Code")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    LinkButton(title: "Use a different email") {
                        codeSent = false
                        email = ""
                    }
                }
            } else {
                VStack(spacing: 16) {
                    EmailField(text: $email, errors: response)

                    FormErrors(errors: response)

                    PrimaryButton(title: "Send Code", isLoading: isLoading) {
                        await requestCode()
                    }

                    LinkButton(title: "Sign in with password instead") {
                        navigationManager.navigate(to: .login)
                    }
                }
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyRestart(navigationManager.loginCodeRestart)
        }
        .onChange(of: navigationManager.loginCodeRestart) { restart in
            applyRestart(restart)
        }
    }

    private func requestCode() async {
        response = await performRequest(loading: $isLoading, context: "request login code") {
            try await client.requestLoginCode(email: email)
        }

        if response?.isSuccess == true || response?.isLoginCodePending == true {
            navigationManager.loginCodeEmail = email
            codeSent = true
        }
    }

    /// Return to the email form (keeping the address) and show why, when the
    /// Enter Code screen sends the user back to request a new code.
    private func applyRestart(_ restart: AuthNavigationManager.LoginCodeRestart?) {
        guard let restart else { return }
        navigationManager.loginCodeRestart = nil
        if let restartEmail = navigationManager.loginCodeEmail {
            email = restartEmail
        }
        codeSent = false
        if let notice = restart.notice {
            response = LoginCodeConfirmation.errorResponse(notice)
        } else {
            response = nil
        }
    }
}

// MARK: - Confirm Login Code

/// Confirm login code view
/// Equivalent to ConfirmLoginCode.js in the React implementation
public struct ConfirmLoginCodeView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    let email: String?

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public init(email: String? = nil) {
        self.email = email
    }

    public var body: some View {
        AuthForm(
            title: "Enter Code",
            subtitle: displayedEmail != nil
                ? "Enter the code we sent to \(displayedEmail!)"
                : "Enter the code from your email"
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    await confirmCode()
                }
                .accessibilityIdentifier("confirm-login-code-submit")

                LinkButton(title: "Request a new code") {
                    navigationManager.restartLoginByCode(notice: nil)
                }

                LinkButton(title: "Sign in with password instead") {
                    navigationManager.navigate(to: .login)
                }
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayedEmail: String? {
        email ?? navigationManager.loginCodeEmail
    }

    private func confirmCode() async {
        let confirmation = LoginCodeConfirmation { code in
            try await client.confirmLoginCode(code: code)
        }
        let result = await confirmation.submit(code: code, loading: $isLoading)
        response = result.response

        switch result.outcome {
        case .signedIn:
            // The client already published the authenticated response; the
            // root view leaves the auth flow. Refresh to pick up the user.
            await authContext.refreshAuth()
        case .nextStep:
            // The auth root renders the newly pending flow (e.g. MFA).
            navigationManager.popToRoot()
        case .restartFlow:
            navigationManager.restartLoginByCode(notice: LoginCodeConfirmation.expiredMessage)
            // Drop the stale pending login-code flow so the auth root stops
            // rendering the Enter Code screen.
            await authContext.refreshAuth()
        case .showErrors:
            break
        }
    }
}

// MARK: - Preview

#Preview("Request Code") {
    NavigationStack {
        RequestLoginCodeView()
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}

#Preview("Confirm Code") {
    NavigationStack {
        ConfirmLoginCodeView(email: "test@example.com")
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
