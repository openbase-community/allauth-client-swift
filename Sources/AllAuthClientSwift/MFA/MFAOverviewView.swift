import Foundation
import SwiftUI
import SwiftyJSON

/// MFA overview/dashboard view
/// Equivalent to MFAOverview.js in the React implementation
public struct MFAOverviewView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var authenticators: [JSON] = []
    @State private var isLoading = false

    private let client = AllAuthClient.shared

    public init() {}

    var totpAuthenticator: JSON? {
        authenticators.first { $0["type"].string == AuthenticatorType.totp.rawValue }
    }

    var recoveryCodesAuthenticator: JSON? {
        authenticators.first { $0["type"].string == AuthenticatorType.recoveryCodes.rawValue }
    }

    var webauthnAuthenticators: [JSON] {
        authenticators.filter { $0["type"].string == AuthenticatorType.webauthn.rawValue }
    }

    var hasTOTP: Bool {
        totpAuthenticator != nil
    }

    var hasRecoveryCodes: Bool {
        recoveryCodesAuthenticator != nil
    }

    var recoveryCodesInfo: (total: Int, unused: Int)? {
        guard let auth = recoveryCodesAuthenticator else { return nil }
        return (
            auth["total_code_count"].intValue,
            auth["unused_code_count"].intValue
        )
    }

    public var body: some View {
        List {
            // TOTP Section
            Section {
                if hasTOTP {
                    NavigationLink {
                        DeactivateTOTPView()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Authenticator App")
                                Text("Enabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    NavigationLink {
                        ActivateTOTPView()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Set up authenticator app")
                        }
                    }
                }
            } header: {
                Label("Authenticator App", systemImage: "lock.rotation")
            } footer: {
                Text("Use an authenticator app like Google Authenticator or Authy to generate one-time codes.")
            }

            // Recovery Codes Section
            Section {
                if hasRecoveryCodes, let info = recoveryCodesInfo {
                    NavigationLink {
                        RecoveryCodesView()
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Recovery Codes")
                                Text("\(info.unused) of \(info.total) remaining")
                                    .font(.caption)
                                    .foregroundColor(info.unused <= 2 ? .red : .secondary)
                            }
                        }
                    }
                } else if hasTOTP {
                    NavigationLink {
                        GenerateRecoveryCodesView()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Generate recovery codes")
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.secondary)
                        Text("Set up authenticator app first")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Recovery Codes", systemImage: "key.fill")
            } footer: {
                Text("Recovery codes can be used to access your account if you lose access to your authenticator.")
            }

            // Security Keys Section
            Section {
                ForEach(Array(webauthnAuthenticators.enumerated()), id: \.offset) { _, authenticator in
                    NavigationLink {
                        UpdateWebAuthnView(authenticator: authenticator)
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text(authenticator["name"].stringValue)
                                Text("Added \(formatDate(authenticator["created_at"].doubleValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if hasTOTP {
                    NavigationLink {
                        AddWebAuthnView()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add security key")
                        }
                    }
                } else if webauthnAuthenticators.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.secondary)
                        Text("Set up authenticator app first")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("Security Keys", systemImage: "person.badge.key.fill")
            } footer: {
                Text("Use a hardware security key or passkey for additional security.")
            }
        }
        .navigationTitle("Two-Factor Authentication")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadAuthenticators()
        }
        .task {
            await loadAuthenticators()
        }
    }

    private func loadAuthenticators() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.getAuthenticators()
            if result.isSuccess {
                authenticators = result["data"].arrayValue
            }
        } catch {
            print("Failed to load authenticators: \(error)")
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "Unknown" }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MFAOverviewView()
            .environmentObject(AuthContext.shared)
    }
}
