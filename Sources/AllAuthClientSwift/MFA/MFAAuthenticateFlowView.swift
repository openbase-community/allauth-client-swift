import Foundation
import SwiftUI
import SwiftyJSON

/// MFA authentication flow view
/// Routes to appropriate MFA method based on available authenticators
/// Equivalent to AuthenticateFlow.js in the React implementation
public struct MFAAuthenticateFlowView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var selectedMethod: String?

    var availableMethods: [String] {
        guard let flow = authContext.getPendingFlow(.mfaAuthenticate) else {
            return []
        }
        return flow["types"].arrayValue.map { $0.stringValue }
    }

    public var body: some View {
        Group {
            if let method = selectedMethod {
                methodView(for: method)
            } else if availableMethods.count == 1, let method = availableMethods.first {
                methodView(for: method)
            } else if availableMethods.isEmpty {
                noMethodsView
            } else {
                methodSelectionView
            }
        }
    }

    var methodSelectionView: some View {
        AuthForm(title: "Two-Factor Authentication", subtitle: "Choose a verification method.") {
            VStack(spacing: 12) {
                ForEach(availableMethods, id: \.self) { method in
                    Button {
                        selectedMethod = method
                    } label: {
                        HStack {
                            Image(systemName: iconFor(method: method))
                                .font(.title2)
                                .foregroundColor(colorFor(method: method))
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(labelFor(method: method))
                                    .fontWeight(.medium)
                                Text(descriptionFor(method: method))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
    }

    var noMethodsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("No Verification Methods")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No two-factor authentication methods are available for your account.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    func methodView(for method: String) -> some View {
        switch method {
        case AuthenticatorType.totp.rawValue:
            AuthenticateTOTPView()
        case AuthenticatorType.recoveryCodes.rawValue:
            AuthenticateRecoveryCodesView()
        case AuthenticatorType.webauthn.rawValue:
            AuthenticateWebAuthnView()
        default:
            Text("Unknown method: \(method)")
        }
    }

    func iconFor(method: String) -> String {
        switch method {
        case AuthenticatorType.totp.rawValue:
            return "lock.rotation"
        case AuthenticatorType.recoveryCodes.rawValue:
            return "key.fill"
        case AuthenticatorType.webauthn.rawValue:
            return "person.badge.key.fill"
        default:
            return "questionmark.circle"
        }
    }

    func colorFor(method: String) -> Color {
        switch method {
        case AuthenticatorType.totp.rawValue:
            return .blue
        case AuthenticatorType.recoveryCodes.rawValue:
            return .orange
        case AuthenticatorType.webauthn.rawValue:
            return .purple
        default:
            return .gray
        }
    }

    func labelFor(method: String) -> String {
        switch method {
        case AuthenticatorType.totp.rawValue:
            return "Authenticator App"
        case AuthenticatorType.recoveryCodes.rawValue:
            return "Recovery Code"
        case AuthenticatorType.webauthn.rawValue:
            return "Security Key"
        default:
            return method
        }
    }

    func descriptionFor(method: String) -> String {
        switch method {
        case AuthenticatorType.totp.rawValue:
            return "Enter a code from your authenticator app"
        case AuthenticatorType.recoveryCodes.rawValue:
            return "Use one of your backup codes"
        case AuthenticatorType.webauthn.rawValue:
            return "Use your hardware security key or passkey"
        default:
            return ""
        }
    }
}

// MARK: - Trust Device View

/// Trust device view after MFA authentication
/// Equivalent to Trust.js in the React implementation
public struct MFATrustDeviceView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Trust This Device?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You won't need to verify with two-factor authentication on this device for a while.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            FormErrors(errors: response)

            VStack(spacing: 12) {
                PrimaryButton(title: "Trust This Device", isLoading: isLoading) {
                    await trustDevice()
                }

                SecondaryButton(title: "Don't Trust", isLoading: false) {
                    await skipTrust()
                }
            }
        }
        .padding()
        .navigationTitle("Trust Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func trustDevice() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.trustDevice()

            if response?.isSuccess == true {
                await authContext.refreshAuth()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }

    private func skipTrust() async {
        // Just proceed without trusting
        await authContext.refreshAuth()
    }
}

// MARK: - Preview

#Preview("Flow") {
    NavigationStack {
        MFAAuthenticateFlowView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}

#Preview("Trust") {
    NavigationStack {
        MFATrustDeviceView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
