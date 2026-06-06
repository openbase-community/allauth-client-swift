import Foundation
import SwiftUI
import SwiftyJSON

/// Reauthentication view
/// Equivalent to Reauthenticate.js in the React implementation
public struct ReauthenticateView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var password = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Confirm Your Identity",
            subtitle: "For security, please enter your password to continue."
        ) {
            VStack(spacing: 16) {
                PasswordField(text: $password, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Confirm", isLoading: isLoading) {
                    await reauthenticate()
                }

                LinkButton(title: "Cancel") {
                    navigationManager.pop()
                }
            }
        }
        .navigationTitle("Confirm Identity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reauthenticate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.reauthenticate(password: password)

            if response?.isSuccess == true {
                await authContext.refreshAuth()
                navigationManager.pop()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

/// Reauthentication flow handler
/// Routes to appropriate reauthentication method based on available options
/// Equivalent to ReauthenticateFlow.js in the React implementation
public struct ReauthenticateFlowView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    public var body: some View {
        Group {
            if authContext.isPending(flow: .mfaReauthenticate) {
                // MFA reauthentication required
                MFAReauthenticateFlowView()
            } else if authContext.isPending(flow: .reauthenticate) {
                // Password reauthentication required
                ReauthenticateView()
            } else {
                // No reauthentication required, shouldn't be here
                Text("No reauthentication required")
                    .onAppear {
                        navigationManager.pop()
                    }
            }
        }
    }
}

// MARK: - MFA Reauthenticate Flow

/// MFA reauthentication flow view
/// Routes to appropriate MFA method based on available authenticators
public struct MFAReauthenticateFlowView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var selectedMethod: String?

    var availableMethods: [String] {
        guard let flow = authContext.getPendingFlow(.mfaReauthenticate) else {
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
            } else {
                methodSelectionView
            }
        }
    }

    var methodSelectionView: some View {
        AuthForm(title: "Verify Your Identity", subtitle: "Choose a verification method.") {
            VStack(spacing: 12) {
                ForEach(availableMethods, id: \.self) { method in
                    Button {
                        selectedMethod = method
                    } label: {
                        HStack {
                            Image(systemName: iconFor(method: method))
                            Text(labelFor(method: method))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Verify Identity")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    func methodView(for method: String) -> some View {
        switch method {
        case AuthenticatorType.totp.rawValue:
            ReauthenticateTOTPView()
        case AuthenticatorType.recoveryCodes.rawValue:
            ReauthenticateRecoveryCodesView()
        case AuthenticatorType.webauthn.rawValue:
            ReauthenticateWebAuthnView()
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReauthenticateView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
