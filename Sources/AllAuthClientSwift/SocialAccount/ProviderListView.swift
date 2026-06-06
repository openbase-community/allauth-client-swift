import Foundation
import SwiftUI
import SwiftyJSON

/// Social provider list for login
/// Equivalent to ProviderList.js in the React implementation
public struct ProviderListView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    let process: AuthProcess
    var onProviderSelected: ((JSON) -> Void)?

    public init(process: AuthProcess = .login, onProviderSelected: ((JSON) -> Void)? = nil) {
        self.process = process
        self.onProviderSelected = onProviderSelected
    }

    var providers: [JSON] {
        return authContext.socialProviders
    }

    public var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(providers.enumerated()), id: \.offset) { _, provider in
                ProviderButton(provider: provider) {
                    onProviderSelected?(provider)
                }
            }
        }
    }
}

/// Button for a single social provider
struct ProviderButton: View {
    let provider: JSON
    let action: () -> Void

    var providerId: String {
        provider["id"].stringValue
    }

    var providerName: String {
        provider["name"].stringValue
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                providerIcon
                    .frame(width: 24, height: 24)

                Text("Continue with \(providerName)")
                    .fontWeight(.medium)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColorFor(provider: providerId))
            .foregroundColor(foregroundColorFor(provider: providerId))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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

// MARK: - Provider Login Handler

/// Handles social provider authentication flow
@MainActor
public class ProviderLoginHandler: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?

    private let client = AllAuthClient.shared

    /// Authenticate with a provider token (e.g., from Sign in with Apple)
    func authenticateWithToken(
        providerId: String,
        accessToken: String,
        process: AuthProcess = .login
    ) async -> JSON? {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.authenticateWithProviderToken(
                providerId: providerId,
                token: accessToken,
                process: process
            )
            return result
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Sign in with")
            .font(.headline)

        ProviderListView()
    }
    .padding()
    .environmentObject(AuthContext.shared)
    .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
}
