import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Request Password Reset

/// Request password reset view
/// Equivalent to RequestPasswordReset.js in the React implementation
public struct RequestPasswordResetView: View {
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var email = ""
    @State private var isLoading = false
    @State private var response: JSON?
    @State private var emailSent = false

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Reset Password",
            subtitle: "Enter your email address and we'll send you a link to reset your password."
        ) {
            if emailSent {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Check Your Email")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("We've sent a password reset link to \(email)")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    LinkButton(title: "Back to Sign In") {
                        navigationManager.navigate(to: .login)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    EmailField(text: $email, errors: response)

                    FormErrors(errors: response)

                    PrimaryButton(title: "Send Reset Link", isLoading: isLoading) {
                        await requestReset()
                    }

                    LinkButton(title: "Back to Sign In") {
                        navigationManager.navigate(to: .login)
                    }
                }
            }
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestReset() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.requestPasswordReset(email: email)

            if response?.isSuccess == true {
                emailSent = true
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Confirm Password Reset Code

/// Confirm password reset code view
/// Equivalent to ConfirmPasswordResetCode.js in the React implementation
public struct ConfirmPasswordResetCodeView: View {
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    public var body: some View {
        AuthForm(
            title: "Enter Reset Code",
            subtitle: "Enter the code from the password reset email."
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify Code", isLoading: isLoading) {
                    await verifyCode()
                }

                LinkButton(title: "Request a new code") {
                    navigationManager.navigate(to: .requestPasswordReset)
                }
            }
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func verifyCode() async {
        isLoading = true
        defer { isLoading = false }

        // Code verification happens as part of the reset flow
        // The actual implementation will depend on the pending flow state
        navigationManager.navigate(to: .resetPassword)
    }
}

// MARK: - Reset Password

/// Reset password with key/code view
/// Equivalent to ResetPassword.js in the React implementation
public struct ResetPasswordView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    let key: String?

    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isLoading = false
    @State private var isValidating = false
    @State private var response: JSON?
    @State private var keyValid = false
    @State private var userEmail: String?

    private let client = AllAuthClient.shared

    init(key: String? = nil) {
        self.key = key
    }

    public var body: some View {
        AuthForm(
            title: "Set New Password",
            subtitle: userEmail != nil ? "Choose a new password for \(userEmail!)" : "Choose a new password for your account."
        ) {
            if isValidating {
                VStack {
                    ProgressView("Validating reset link...")
                }
            } else if !keyValid && key != nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)

                    Text("Invalid or Expired Link")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This password reset link is invalid or has expired. Please request a new one.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    PrimaryButton(title: "Request New Link", isLoading: false) {
                        navigationManager.navigate(to: .requestPasswordReset)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    PasswordField("New Password", text: $password, errors: response)

                    PasswordField("Confirm Password", text: $passwordConfirm, errors: response, fieldName: "password2")

                    FormErrors(errors: response)

                    PrimaryButton(title: "Reset Password", isLoading: isLoading) {
                        await resetPassword()
                    }
                }
            }
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let key = key {
                await validateKey(key)
            } else {
                keyValid = true
            }
        }
    }

    private func validateKey(_ key: String) async {
        isValidating = true
        defer { isValidating = false }

        do {
            let result = try await client.getPasswordReset(key: key)
            if result.isSuccess {
                keyValid = true
                userEmail = result["data"]["user"]["email"].string
            } else {
                keyValid = false
            }
        } catch {
            keyValid = false
        }
    }

    private func resetPassword() async {
        // Client-side validation
        if password != passwordConfirm {
            response = JSON(["errors": [["param": "password2", "message": "Passwords do not match"]]])
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let resetKey = key else {
                response = JSON(["errors": [["message": "Missing reset key"]]])
                return
            }

            response = try await client.resetPassword(key: resetKey, password: password)

            if response?.isSuccess == true {
                // Password reset successful, navigate to login
                navigationManager.navigate(to: .login)
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Preview

#Preview("Request Reset") {
    NavigationStack {
        RequestPasswordResetView()
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}

#Preview("Reset Password") {
    NavigationStack {
        ResetPasswordView(key: "test-key")
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
