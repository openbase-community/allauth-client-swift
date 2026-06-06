import Foundation
import SwiftUI
import SwiftyJSON

/// Manage connected social accounts view
/// Equivalent to ManageProviders.js in the React implementation
public struct ManageProvidersView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var connectedProviders: [JSON] = []
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    private let client = AllAuthClient.shared

    var availableProviders: [JSON] {
        let connectedIds = Set(connectedProviders.map { $0["provider"]["id"].stringValue })
        return authContext.socialProviders.filter { provider in
            !connectedIds.contains(provider["id"].stringValue)
        }
    }

    public init() {}

    public var body: some View {
        List {
            // Connected accounts
            Section {
                if connectedProviders.isEmpty && !isLoading {
                    Text("No connected accounts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(connectedProviders.enumerated()), id: \.offset) { _, account in
                        ConnectedProviderRow(
                            account: account,
                            canDisconnect: connectedProviders.count > 1 || authContext.user?["has_usable_password"].boolValue == true,
                            onDisconnect: { await disconnect(account: account) }
                        )
                    }
                }
            } header: {
                Text("Connected Accounts")
            } footer: {
                if connectedProviders.count == 1 && authContext.user?["has_usable_password"].boolValue == false {
                    Text("You must set a password before disconnecting your only connected account.")
                }
            }

            // Available providers to connect
            if !availableProviders.isEmpty {
                Section("Connect More Accounts") {
                    ForEach(Array(availableProviders.enumerated()), id: \.offset) { _, provider in
                        ProviderButton(provider: provider) {
                            // Handle connecting new provider
                            // This would typically open an OAuth flow
                        }
                    }
                }
            }

            if showSuccess {
                Section {
                    SuccessAlert(message: successMessage) {
                        showSuccess = false
                    }
                }
            }
        }
        .navigationTitle("Connected Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadProviders()
        }
        .task {
            await loadProviders()
        }
    }

    private func loadProviders() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.getProviders()
            if result.isSuccess {
                connectedProviders = result["data"].arrayValue
            }
        } catch {
            print("Failed to load providers: \(error)")
        }
    }

    private func disconnect(account: JSON) async {
        do {
            let result = try await client.disconnectProvider(
                providerId: account["provider"]["id"].stringValue,
                accountUid: account["uid"].stringValue
            )

            if result.isSuccess {
                successMessage = "Account disconnected"
                showSuccess = true
                await loadProviders()
            }
        } catch {
            print("Failed to disconnect: \(error)")
        }
    }
}

/// Row for a connected provider account
struct ConnectedProviderRow: View {
    let account: JSON
    let canDisconnect: Bool
    let onDisconnect: () async -> Void

    @State private var showDisconnectConfirmation = false
    @State private var isDisconnecting = false

    var providerId: String {
        account["provider"]["id"].stringValue
    }

    var providerName: String {
        account["provider"]["name"].stringValue
    }

    var displayName: String {
        account["display"].stringValue
    }

    public var body: some View {
        HStack {
            providerIcon
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(providerName)
                    .fontWeight(.medium)

                Text(displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if canDisconnect {
                Button {
                    showDisconnectConfirmation = true
                } label: {
                    if isDisconnecting {
                        ProgressView()
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Disconnect \(providerName)?", isPresented: $showDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) {
                isDisconnecting = true
                Task {
                    await onDisconnect()
                    isDisconnecting = false
                }
            }
        } message: {
            Text("You will no longer be able to sign in with this \(providerName) account.")
        }
    }

    @ViewBuilder
    var providerIcon: some View {
        switch providerId {
        case "google":
            Image(systemName: "g.circle.fill")
        case "apple":
            Image(systemName: "apple.logo")
        case "facebook":
            Image(systemName: "f.circle.fill")
        case "twitter":
            Image(systemName: "at.circle.fill")
        case "github":
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        case "microsoft":
            Image(systemName: "square.grid.2x2.fill")
        default:
            Image(systemName: "link.circle.fill")
        }
    }

    var iconColor: Color {
        switch providerId {
        case "google":
            return .red
        case "apple":
            return .black
        case "facebook":
            return .blue
        case "twitter":
            return Color(red: 0.11, green: 0.63, blue: 0.95)
        case "github":
            return .black
        case "microsoft":
            return .blue
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ManageProvidersView()
            .environmentObject(AuthContext.shared)
    }
}
