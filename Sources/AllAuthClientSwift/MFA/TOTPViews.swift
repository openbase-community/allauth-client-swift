import Foundation
import CoreImage.CIFilterBuiltins
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

            // QR code generated from the otpauth URI
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

                CodeField(text: $code, errors: response, format: .numeric)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify & Enable", isLoading: isActivating) {
                    await activateTOTP()
                }
            }
        }
    }

    var successView: some View {
        StatusView(
            icon: "checkmark.circle.fill",
            color: .green,
            title: "Authenticator Enabled!",
            message: "Two-factor authentication is now enabled for your account.",
            buttonTitle: "Continue"
        ) {
            dismiss()
        }
    }

    var errorView: some View {
        StatusView(
            icon: "exclamationmark.triangle.fill",
            color: .red,
            title: "Failed to Load",
            spacing: 16,
            buttonTitle: "Try Again"
        ) {
            await loadTOTPData()
        }
    }

    private func loadTOTPData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            totpData = try await client.getTOTPAuthenticator()
        } catch {
            AuthDiagnostics.log(
                "ActivateTOTPView",
                "failed to load TOTP data",
                metadata: ["error": "\(error)"]
            )
        }
    }

    private func activateTOTP() async {
        response = await performRequest(loading: $isActivating, context: "activate TOTP") {
            try await client.activateTOTP(code: code)
        }

        if response?.isSuccess == true {
            showSuccess = true
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
        response = await performRequest(loading: $isLoading, context: "deactivate TOTP") {
            try await client.deactivateTOTP()
        }

        if response?.isSuccess == true {
            dismiss()
        }
    }
}

// MARK: - TOTP Code Form

/// Shared form for the TOTP authenticate/reauthenticate flows
struct TOTPCodeForm<Footer: View>: View {
    let title: String
    let subtitle: String
    let navigationTitle: String
    let submit: @MainActor (String) async throws -> JSON
    let onSuccess: @MainActor () async -> Void
    @ViewBuilder let footer: () -> Footer

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    var body: some View {
        AuthForm(
            title: title,
            subtitle: subtitle
        ) {
            VStack(spacing: 16) {
                CodeField(text: $code, errors: response, format: .numeric)

                FormErrors(errors: response)

                PrimaryButton(title: "Verify", isLoading: isLoading) {
                    await verify()
                }

                footer()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func verify() async {
        response = await performRequest(loading: $isLoading, context: "verify TOTP code") {
            try await submit(code)
        }

        if response?.isSuccess == true {
            await onSuccess()
        }
    }
}

// MARK: - Authenticate TOTP

/// TOTP authentication view (during MFA flow)
/// Equivalent to AuthenticateTOTP.js in the React implementation
public struct AuthenticateTOTPView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    private let client = AllAuthClient.shared

    public var body: some View {
        TOTPCodeForm(
            title: "Two-Factor Authentication",
            subtitle: "Enter the code from your authenticator app.",
            navigationTitle: "Verify",
            submit: { code in
                try await client.authenticateTOTP(code: code)
            },
            onSuccess: {
                await authContext.refreshAuth()
            }
        ) {
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
}

// MARK: - Reauthenticate TOTP

/// TOTP reauthentication view
/// Equivalent to ReauthenticateTOTP.js in the React implementation
public struct ReauthenticateTOTPView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    private let client = AllAuthClient.shared

    public var body: some View {
        TOTPCodeForm(
            title: "Verify Your Identity",
            subtitle: "Enter the code from your authenticator app to continue.",
            navigationTitle: "Verify Identity",
            submit: { code in
                try await client.reauthenticateTOTP(code: code)
            },
            onSuccess: {
                await authContext.refreshAuth()
                navigationManager.pop()
            }
        ) {
            LinkButton(title: "Cancel") {
                navigationManager.pop()
            }
        }
    }
}

// MARK: - QR Code View

/// Displays a QR code generated from the given content string
public struct QRCodeView: View {
    let content: String

    private let qrImage: UIImage?

    public init(content: String) {
        self.content = content
        self.qrImage = Self.generateQRCode(from: content)
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("Unable to generate QR code")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private static func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        // Scale up so the code stays crisp when resized by SwiftUI
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
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
