import Foundation
import SwiftUI
import SwiftyJSON

public typealias SocialProviderSelectionHandler = (_ provider: JSON, _ process: AuthProcess) async throws -> JSON

/// Social provider list for login and account connection.
public struct ProviderListView: View {
    public static let builtInProviderIds: Set<String> = ["apple"]

    @EnvironmentObject var authContext: AuthContext

    let process: AuthProcess
    let providerOverride: [JSON]?
    let onProviderSelected: SocialProviderSelectionHandler?
    let onSuccess: ((JSON) -> Void)?
    let onError: ((Error) -> Void)?

    @State private var selectedProviderId: String?
    @State private var providerError: String?

    public init(
        process: AuthProcess = .login,
        providers: [JSON]? = nil,
        onProviderSelected: SocialProviderSelectionHandler? = nil,
        onSuccess: ((JSON) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.process = process
        self.providerOverride = providers
        self.onProviderSelected = onProviderSelected
        self.onSuccess = onSuccess
        self.onError = onError
    }

    var providers: [JSON] {
        providerOverride ?? authContext.socialProviders
    }

    var availableProviders: [JSON] {
        providers.filter { provider in
            onProviderSelected != nil || Self.builtInProviderIds.contains(provider["id"].stringValue)
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(availableProviders.enumerated()), id: \.offset) { _, provider in
                let providerId = provider["id"].stringValue

                if providerId == "apple" && onProviderSelected == nil {
                    AppleSignInButton(
                        process: process,
                        onSuccess: handleSuccess,
                        onError: handleError
                    )
                } else {
                    ProviderButton(
                        provider: provider,
                        isLoading: selectedProviderId == providerId
                    ) {
                        Task {
                            await handleProviderSelected(provider)
                        }
                    }
                }
            }

            if let providerError {
                ErrorAlert(message: providerError) {
                    self.providerError = nil
                }
            }
        }
    }

    private func handleProviderSelected(_ provider: JSON) async {
        guard let onProviderSelected else {
            providerError = "Native sign-in is not configured for \(provider["name"].stringValue)."
            return
        }

        selectedProviderId = provider["id"].stringValue
        providerError = nil
        defer { selectedProviderId = nil }

        do {
            let result = try await onProviderSelected(provider, process)
            handleSuccess(result)
        } catch {
            handleError(error)
        }
    }

    private func handleSuccess(_ result: JSON) {
        if result.isSuccess {
            Task {
                await authContext.refreshAuth()
            }
        }
        onSuccess?(result)
    }

    private func handleError(_ error: Error) {
        providerError = error.localizedDescription
        onError?(error)
    }
}

struct ProviderButton: View {
    let provider: JSON
    let isLoading: Bool
    let action: () -> Void

    var providerId: String {
        provider["id"].stringValue
    }

    var providerName: String {
        provider["name"].stringValue
    }

    var body: some View {
        Button(action: action) {
            HStack {
                providerIcon
                    .frame(width: 24, height: 24)

                Text("Continue with \(providerName)")
                    .fontWeight(.medium)

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColorFor(provider: providerId))
            .foregroundColor(foregroundColorFor(provider: providerId))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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

    func backgroundColorFor(provider: String) -> Color {
        switch provider {
        case "google":
            return Color.white
        case "apple":
            return Color.black
        case "facebook":
            return Color(red: 0.23, green: 0.35, blue: 0.60)
        case "twitter":
            return Color(red: 0.11, green: 0.63, blue: 0.95)
        case "github":
            return Color(red: 0.13, green: 0.13, blue: 0.13)
        case "microsoft":
            return Color(red: 0.95, green: 0.95, blue: 0.95)
        default:
            return Color(.systemGray5)
        }
    }

    func foregroundColorFor(provider: String) -> Color {
        switch provider {
        case "google", "microsoft":
            return .black
        case "apple", "facebook", "twitter", "github":
            return .white
        default:
            return .primary
        }
    }
}

@MainActor
public class ProviderLoginHandler: ObservableObject {
    @Published public var isLoading = false
    @Published public var error: String?

    private let client = AllAuthClient.shared

    public init() {}

    public func authenticateWithToken(
        providerId: String,
        token: [String: Any],
        process: AuthProcess = .login
    ) async -> JSON? {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.authenticateWithProviderToken(
                providerId: providerId,
                token: token,
                process: process
            )
            return result
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    public func authenticateWithToken(
        providerId: String,
        accessToken: String,
        process: AuthProcess = .login
    ) async -> JSON? {
        await authenticateWithToken(
            providerId: providerId,
            token: ["access_token": accessToken],
            process: process
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Sign in with")
            .font(.headline)

        ProviderListView()
    }
    .padding()
    .environmentObject(AuthContext.shared)
}
