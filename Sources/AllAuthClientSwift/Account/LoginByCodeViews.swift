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

                    NavigationLink {
                        ConfirmLoginCodeView(email: email)
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
    }

    private func requestCode() async {
        response = await performRequest(loading: $isLoading, context: "request login code") {
            try await client.requestLoginCode(email: email)
        }

        if response?.isSuccess == true || response?.isLoginCodePending == true {
            codeSent = true
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
            subtitle: email != nil
                ? "Enter the code we sent to \(email!)"
                : "Enter the code from your email"
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    await confirmCode()
                }

                LinkButton(title: "Request a new code") {
                    navigationManager.pop()
                }

                LinkButton(title: "Sign in with password instead") {
                    navigationManager.navigate(to: .login)
                }
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func confirmCode() async {
        response = await performRequest(loading: $isLoading, context: "confirm login code") {
            try await client.confirmLoginCode(code: code.normalizedCode)
        }

        if response?.isSuccess == true {
            // Login successful, navigation handled by auth context
            await authContext.refreshAuth()
        } else if response?["status"].intValue == 409 {
            navigationManager.popToRoot()
            navigationManager.navigate(to: .requestLoginCode)
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
