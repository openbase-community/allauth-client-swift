import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Activate TOTP

/// TOTP activation view
/// Equivalent to ActivateTOTP.js in the React implementation
public struct ActivateTOTPView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    @State private var totpData: JSON?
    @State private var code = ""
    @State private var isLoading = false
    @State private var isActivating = false
    @State private var response: JSON?
    @State private var showSuccess = false

    private let client = AllAuthClient.shared

    var totpUri: String? {
        totpData?["data"]["totp"]["totp_url"].string
    }

    var secret: String? {
        totpData?["data"]["totp"]["secret"].string
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading...")
                } else if showSuccess {
                    successView
                } else if let _ = totpData {
                    setupView
                } else {
                    errorView
                }
            }
            .padding()
        }
        .navigationTitle("Set Up Authenticator")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTOTPData()
        }
    }

    var setupView: some View {
        VStack(spacing: 24) {
            // Instructions
            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Scan QR Code")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Open your authenticator app and scan this QR code.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // QR Code placeholder - in a real app, generate QR from totpUri
            if let uri = totpUri {
                QRCodeView(content: uri)
                    .frame(width: 200, height: 200)
            }

            // Manual entry section
            if let secret = secret {
                VStack(spacing: 8) {
                    Text("Can't scan? Enter this code manually:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(secret)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    Button {
                        UIPasteboard.general.string = secret
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                }
            }

            Divider()

            // Verification
            VStack(spacing: 16) {
                Text("Enter the 6-digit code from your app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify & Enable", isLoading: isActivating) {
                    await activateTOTP()
                }
            }
        }
    }

    var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Authenticator Enabled!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Two-factor authentication is now enabled for your account.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Continue", isLoading: false) {
                dismiss()
            }
        }
    }

    var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Failed to Load")
                .font(.title2)
                .fontWeight(.semibold)

            PrimaryButton(title: "Try Again", isLoading: false) {
                Task { await loadTOTPData() }
            }
        }
    }

    private func loadTOTPData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            totpData = try await client.getTOTPAuthenticator()
        } catch {
            print("Failed to load TOTP data: \(error)")
        }
    }

    private func activateTOTP() async {
        isActivating = true
        defer { isActivating = false }

        do {
            response = try await client.activateTOTP(code: code)

            if response?.isSuccess == true {
                showSuccess = true
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Deactivate TOTP

/// TOTP deactivation view
/// Equivalent to DeactivateTOTP.js in the React implementation
public struct DeactivateTOTPView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var response: JSON?
    @State private var showConfirmation = false

    private let client = AllAuthClient.shared

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("Disable Authenticator App?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This will remove two-factor authentication from your account. You can set it up again at any time.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            FormErrors(errors: response)

            VStack(spacing: 12) {
                DestructiveButton(title: "Disable", isLoading: isLoading) {
                    await deactivateTOTP()
                }

                SecondaryButton(title: "Cancel", isLoading: false) {
                    dismiss()
                }
            }
        }
        .padding()
        .navigationTitle("Disable Authenticator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deactivateTOTP() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.deactivateTOTP()

            if response?.isSuccess == true {
                dismiss()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Authenticate TOTP

/// TOTP authentication view (during MFA flow)
/// Equivalent to AuthenticateTOTP.js in the React implementation
public struct AuthenticateTOTPView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Two-Factor Authentication",
            subtitle: "Enter the code from your authenticator app."
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify", isLoading: isLoading) {
                    await authenticate()
                }

                // Alternative methods
                VStack(spacing: 8) {
                    if authContext.availableMFATypes.contains(AuthenticatorType.recoveryCodes.rawValue) {
                        LinkButton(title: "Use recovery code instead") {
                            navigationManager.navigate(to: .mfaAuthenticate)
                        }
                    }

                    if authContext.availableMFATypes.contains(AuthenticatorType.webauthn.rawValue) {
                        LinkButton(title: "Use security key instead") {
                            // Navigate to WebAuthn auth
                        }
                    }
                }
            }
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authenticate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.authenticateTOTP(code: code)

            if response?.isSuccess == true {
                await authContext.refreshAuth()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Reauthenticate TOTP

/// TOTP reauthentication view
/// Equivalent to ReauthenticateTOTP.js in the React implementation
public struct ReauthenticateTOTPView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Verify Your Identity",
            subtitle: "Enter the code from your authenticator app to continue."
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify", isLoading: isLoading) {
                    await reauthenticate()
                }

                LinkButton(title: "Cancel") {
                    navigationManager.pop()
                }
            }
        }
        .navigationTitle("Verify Identity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reauthenticate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.reauthenticateTOTP(code: code)

            if response?.isSuccess == true {
                await authContext.refreshAuth()
                navigationManager.pop()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - QR Code View

/// Simple QR code display view
/// In production, you would use a QR code generation library
public struct QRCodeView: View {
    let content: String


    public var body: some View {
        // Placeholder - in production, generate actual QR code
        // using CoreImage CIQRCodeGenerator or a library
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)

            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 100))
                    .foregroundColor(.black)

                Text("QR Code")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Activate") {
    NavigationStack {
        ActivateTOTPView()
            .environmentObject(AuthContext.shared)
    }
}

#Preview("Authenticate") {
    NavigationStack {
        AuthenticateTOTPView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
