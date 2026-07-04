import Foundation
import SwiftUI
import SwiftyJSON

/// Provider signup view - complete signup after social authentication
/// Equivalent to ProviderSignup.js in the React implementation
public struct ProviderSignupView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var email = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    var pendingFlow: JSON? {
        return authContext.getPendingFlow(.providerSignup)
    }

    var providerName: String {
        guard let flow = pendingFlow,
              let providerId = flow["provider"]["id"].string else {
            return "Social Account"
        }
        return authContext.provider(byId: providerId)?["name"].string ?? providerId
    }

    public var body: some View {
        AuthForm(
            title: "Complete Your Signup",
            subtitle: "You're signing up with \(providerName). Please provide an email address."
        ) {
            VStack(spacing: 16) {
                EmailField(text: $email, errors: response)

                FormErrors(errors: response)

                PrimaryButton(title: "Complete Signup", isLoading: isLoading) {
                    await completeSignup()
                }

                LinkButton(title: "Cancel") {
                    Task {
                        _ = try? await client.logout()
                        authContext.clearAuth()
                    }
                }
            }
        }
        .navigationTitle("Complete Signup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func completeSignup() async {
        response = await performRequest(loading: $isLoading, context: "complete provider signup") {
            try await client.completeProviderSignup(email: email)
        }

        if response?.isSuccess == true {
            await authContext.refreshAuth()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProviderSignupView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
