import SwiftUI
import SwiftyJSON

/// Root view that handles auth state routing
/// Equivalent to Root.js in the React implementation
public struct AllAuthRootView<AuthenticatedContent: View>: View {
    @EnvironmentObject var authContext: AuthContext
    @StateObject private var navigationManager: AuthNavigationManager

    private let authenticatedContent: () -> AuthenticatedContent
    private let onLoginShake: (() -> Void)?
    private let onSocialProviderSelected: SocialProviderSelectionHandler?
    private let onLoginBack: (() -> Void)?

    public init(
        onLoginShake: (() -> Void)? = nil,
        onSocialProviderSelected: SocialProviderSelectionHandler? = nil,
        onLoginBack: (() -> Void)? = nil,
        @ViewBuilder authenticatedContent: @escaping () -> AuthenticatedContent
    ) {
        let context = AuthContext.shared
        _navigationManager = StateObject(wrappedValue: AuthNavigationManager(authContext: context))
        self.authenticatedContent = authenticatedContent
        self.onLoginShake = onLoginShake
        self.onSocialProviderSelected = onSocialProviderSelected
        self.onLoginBack = onLoginBack
    }

    public var body: some View {
        Group {
            if authContext.isLoading {
                AllAuthLoadingView()
            } else if authContext.isAuthenticated && !authContext.requiresReauthentication && !hasPendingMandatoryFlow {
                authenticatedContent()
                    .environmentObject(navigationManager)
            } else {
                AllAuthUnauthenticatedRootView(
                    onLoginShake: onLoginShake,
                    onSocialProviderSelected: onSocialProviderSelected,
                    onLoginBack: onLoginBack
                )
            }
        }
        .environmentObject(navigationManager)
        .onChange(of: authContext.lastAuthChange) { change in
            if let change = change {
                navigationManager.handleAuthChange(change)
            }
        }
    }

    private var hasPendingMandatoryFlow: Bool {
        return authContext.isPending(flow: .verifyEmail) ||
            authContext.isPending(flow: .mfaAuthenticate)
    }
}

/// Loading view shown during initial auth check
public struct AllAuthLoadingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading...")
                .foregroundColor(.secondary)
        }
    }
}

/// View shown when user is not authenticated
public struct AllAuthUnauthenticatedRootView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    private let onLoginShake: (() -> Void)?
    private let onSocialProviderSelected: SocialProviderSelectionHandler?
    private let onLoginBack: (() -> Void)?

    public init(
        onLoginShake: (() -> Void)? = nil,
        onSocialProviderSelected: SocialProviderSelectionHandler? = nil,
        onLoginBack: (() -> Void)? = nil
    ) {
        self.onLoginShake = onLoginShake
        self.onSocialProviderSelected = onSocialProviderSelected
        self.onLoginBack = onLoginBack
    }

    public var body: some View {
        NavigationStack(path: $navigationManager.path) {
            initialView
                .navigationDestination(for: AuthRoute.self) { route in
                    destinationView(for: route)
                }
        }
    }

    @ViewBuilder
    private var initialView: some View {
        if authContext.isPending(flow: .verifyEmail) {
            VerificationEmailSentView()
        } else if authContext.isPending(flow: .mfaAuthenticate) {
            MFAAuthenticateFlowView()
        } else if authContext.isPending(flow: .mfaReauthenticate) {
            MFAReauthenticateFlowView()
        } else if authContext.isPending(flow: .reauthenticate) {
            ReauthenticateView()
        } else if authContext.isPending(flow: .providerSignup) {
            ProviderSignupView()
        } else if authContext.isPending(flow: .mfaTrust) {
            MFATrustDeviceView()
        } else {
            LoginView(
                onShake: onLoginShake,
                onSocialProviderSelected: onSocialProviderSelected,
                onBack: onLoginBack
            )
        }
    }

    @ViewBuilder
    public func destinationView(for route: AuthRoute) -> some View {
        switch route {
        case .login:
            LoginView(
                onShake: onLoginShake,
                onSocialProviderSelected: onSocialProviderSelected
            )
        case .signup:
            SignupView()
        case .verifyEmail:
            VerificationEmailSentView()
        case .requestLoginCode:
            RequestLoginCodeView()
        case .confirmLoginCode:
            ConfirmLoginCodeView()
        case .providerSignup:
            ProviderSignupView()
        case .mfaAuthenticate:
            MFAAuthenticateFlowView()
        case .mfaReauthenticate:
            MFAReauthenticateFlowView()
        case .reauthenticate:
            ReauthenticateView()
        case .mfaTrust:
            MFATrustDeviceView()
        case .mfaWebAuthnSignup:
            AddWebAuthnView()
        case .resetPassword:
            ResetPasswordView()
        case .requestPasswordReset:
            RequestPasswordResetView()
        case .changePassword:
            ChangePasswordView()
        case .changeEmail:
            ChangeEmailView()
        case .mfaOverview:
            MFAOverviewView()
        case .sessions:
            SessionsView()
        case .socialAccounts:
            ManageProvidersView(onSocialProviderSelected: onSocialProviderSelected)
        }
    }
}

/// Helper view builder for authenticated navigation destinations
public struct AllAuthAccountDestinations: View {
    let route: AuthRoute
    let onSocialProviderSelected: SocialProviderSelectionHandler?

    public init(
        route: AuthRoute,
        onSocialProviderSelected: SocialProviderSelectionHandler? = nil
    ) {
        self.route = route
        self.onSocialProviderSelected = onSocialProviderSelected
    }

    public var body: some View {
        switch route {
        case .changePassword:
            ChangePasswordView()
        case .changeEmail:
            ChangeEmailView()
        case .mfaOverview:
            MFAOverviewView()
        case .sessions:
            SessionsView()
        case .socialAccounts:
            ManageProvidersView(onSocialProviderSelected: onSocialProviderSelected)
        case .reauthenticate:
            ReauthenticateView()
        case .mfaReauthenticate:
            MFAReauthenticateFlowView()
        default:
            Text("Unknown route")
        }
    }
}
