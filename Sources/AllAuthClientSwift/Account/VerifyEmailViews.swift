import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Verify Email

/// Email verification view
/// Equivalent to VerifyEmail.js in the React implementation
public struct VerifyEmailView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    let key: String?

    @State private var isLoading = false
    @State private var isVerifying = false
    @State private var response: JSON?
    @State private var verificationStatus: VerificationStatus = .pending

    private let client = AllAuthClient.shared

    enum VerificationStatus {
        case pending
        case success
        case failed
        case alreadyVerified
    }

    init(key: String? = nil) {
        self.key = key
    }

    public var body: some View {
        AuthForm(title: "Verify Email") {
            VStack(spacing: 24) {
                switch verificationStatus {
                case .pending:
                    if isVerifying {
                        ProgressView("Verifying your email...")
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            if key != nil {
                                Text("Click below to verify your email address.")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                PrimaryButton(title: "Verify Email", isLoading: isLoading) {
                                    await verifyEmail()
                                }
                            } else {
                                Text("Please check your email and click the verification link.")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }

                case .success:
                    StatusView(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        title: "Email Verified!",
                        message: "Your email address has been verified successfully.",
                        spacing: 16,
                        buttonTitle: authContext.isAuthenticated ? "Continue" : "Sign In"
                    ) {
                        if authContext.isAuthenticated {
                            navigationManager.popToRoot()
                        } else {
                            navigationManager.navigate(to: .login)
                        }
                    }

                case .failed:
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)

                        Text("Verification Failed")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("The verification link is invalid or has expired.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        FormErrors(errors: response)

                        PrimaryButton(title: "Request New Link", isLoading: false) {
                            // Navigate to email settings if logged in, otherwise login
                            if authContext.isAuthenticated {
                                navigationManager.navigate(to: .changeEmail)
                            } else {
                                navigationManager.navigate(to: .login)
                            }
                        }
                    }

                case .alreadyVerified:
                    StatusView(
                        icon: "checkmark.seal.fill",
                        color: .green,
                        title: "Already Verified",
                        message: "This email address has already been verified.",
                        spacing: 16,
                        buttonTitle: "Continue"
                    ) {
                        if authContext.isAuthenticated {
                            navigationManager.popToRoot()
                        } else {
                            navigationManager.navigate(to: .login)
                        }
                    }
                }
            }
        }
        .navigationTitle("Verify Email")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let key = key {
                await checkKey(key)
            }
        }
    }

    private func checkKey(_ key: String) async {
        isVerifying = true
        defer { isVerifying = false }

        do {
            let result = try await client.getEmailVerification(key: key)
            if result.isSuccess {
                // Key is valid, but email not yet verified
                verificationStatus = .pending
            } else if result["status"].intValue == 409 {
                // Already verified
                verificationStatus = .alreadyVerified
            } else {
                verificationStatus = .failed
                response = result
            }
        } catch {
            verificationStatus = .failed
        }
    }

    private func verifyEmail() async {
        guard let key = key else { return }

        response = await performRequest(loading: $isLoading, context: "verify email") {
            try await client.verifyEmail(key: key)
        }

        if response?.isSuccess == true {
            verificationStatus = .success
            await authContext.refreshAuth()
        } else {
            verificationStatus = .failed
        }
    }
}

// MARK: - Verify Email by Code

/// Email verification by code view
/// Equivalent to VerifyEmailByCode.js in the React implementation
public struct VerifyEmailByCodeView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Verify Email",
            subtitle: "Enter the verification code sent to your email."
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify", isLoading: isLoading) {
                    await verifyCode()
                }
            }
        }
        .navigationTitle("Verify Email")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func verifyCode() async {
        response = await performRequest(loading: $isLoading, context: "verify email code") {
            try await client.verifyEmail(key: code.normalizedCode)
        }

        if response?.isSuccess == true {
            await authContext.refreshAuth()
            // Navigation handled by auth state change
        }
    }
}

// MARK: - Verification Email Sent

/// View shown after signup when verification is required
/// Equivalent to VerificationEmailSent.js in the React implementation
public struct VerificationEmailSentView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var isCheckingVerification = false
    @State private var stillPendingAfterCheck = false

    var email: String? {
        return authContext.user?["email"].string
    }

    public var body: some View {
        AuthForm(title: "Verify Your Email") {
            VStack(spacing: 24) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("Check your inbox")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let email = email {
                        Text("We've sent a verification email to:")
                            .foregroundColor(.secondary)

                        Text(email)
                            .fontWeight(.medium)
                    } else {
                        Text("We've sent a verification email to your address.")
                            .foregroundColor(.secondary)
                    }
                }

                Text("Click the link in the email to verify your account. If you don't see it, check your spam folder.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                VStack(spacing: 12) {
                    PrimaryButton(title: "I've Verified My Email", isLoading: isCheckingVerification) {
                        await checkVerification()
                    }

                    if stillPendingAfterCheck {
                        Text("Not verified yet — if you haven't clicked the link, check your inbox or spam folder. Already clicked it? Sign in again to continue.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        SecondaryButton(title: "Back to Sign In", isLoading: false) {
                            await signOut()
                        }
                    }

                    LinkButton(title: "Didn't receive it? Manage email addresses") {
                        navigationManager.navigate(to: .changeEmail)
                    }

                    LinkButton(title: "Sign out") {
                        Task {
                            await signOut()
                        }
                    }
                }
            }
        }
        .navigationTitle("Verify Email")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Re-checks the session's auth state. If the email was verified in a way
    /// that completed this session's login, the auth change dismisses this
    /// screen automatically; otherwise surface next steps inline.
    private func checkVerification() async {
        stillPendingAfterCheck = false
        isCheckingVerification = true
        defer { isCheckingVerification = false }

        await authContext.refreshAuth()

        if !authContext.isAuthenticated && authContext.isPending(flow: .verifyEmail) {
            stillPendingAfterCheck = true
        }
    }

    /// Clears the stalled pending-verification session so the user lands back
    /// on the sign-in screen, where logging in succeeds once the email address
    /// has been verified (e.g. via the link opened in a browser).
    private func signOut() async {
        _ = try? await AllAuthClient.shared.logout()
        authContext.clearAuth()
    }
}

// MARK: - Preview

#Preview("Verify Email") {
    NavigationStack {
        VerifyEmailView(key: "test-key")
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}

#Preview("Email Sent") {
    NavigationStack {
        VerificationEmailSentView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
