import Foundation
import SwiftUI
import SwiftyJSON
import Combine

/// Custom property wrapper for accessing auth context
/// Equivalent to useAuth() hook in React
@propertyWrapper
@MainActor
public struct UseAuth: DynamicProperty {
    @EnvironmentObject private var authContext: AuthContext

    public init() {}

    public var wrappedValue: JSON? {
        return authContext.auth
    }
}

/// Property wrapper for accessing current user
/// Equivalent to useUser() hook in React
@propertyWrapper
@MainActor
public struct UseUser: DynamicProperty {
    @EnvironmentObject private var authContext: AuthContext

    public init() {}

    public var wrappedValue: JSON? {
        return authContext.user
    }
}

/// Property wrapper for accessing config
/// Equivalent to useConfig() hook in React
@propertyWrapper
@MainActor
public struct UseConfig: DynamicProperty {
    @EnvironmentObject private var authContext: AuthContext

    public init() {}

    public var wrappedValue: JSON? {
        return authContext.config
    }
}

// MARK: - View Modifiers for Auth State

/// View modifier that only shows content when authenticated
public struct AuthenticatedViewModifier: ViewModifier {
    @EnvironmentObject var authContext: AuthContext

    public func body(content: Content) -> some View {
        if authContext.isAuthenticated {
            content
        }
    }
}

/// View modifier that only shows content when not authenticated
public struct AnonymousViewModifier: ViewModifier {
    @EnvironmentObject var authContext: AuthContext

    public func body(content: Content) -> some View {
        if !authContext.isAuthenticated {
            content
        }
    }
}

public extension View {
    /// Only show this view when user is authenticated
    func authenticatedOnly() -> some View {
        modifier(AuthenticatedViewModifier())
    }

    /// Only show this view when user is not authenticated
    func anonymousOnly() -> some View {
        modifier(AnonymousViewModifier())
    }
}

// MARK: - Auth Change Observer

/// Observable object that tracks auth state changes
@MainActor
public class AuthChangeObserver: ObservableObject {
    @Published var previousAuth: JSON?
    @Published var currentAuth: JSON?
    @Published var lastChange: AuthChangeEvent?

    private var cancellables = Set<AnyCancellable>()

    init(context: AuthContext) {
        context.$auth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newAuth in
                self?.previousAuth = self?.currentAuth
                self?.currentAuth = newAuth
                self?.lastChange = context.detectAuthChange(
                    from: self?.previousAuth,
                    to: newAuth
                )
            }
            .store(in: &cancellables)
    }
}

// MARK: - Auth Status View Model

/// View model providing parsed auth information
/// Equivalent to useAuthStatus() hook in React
@MainActor
public class AuthStatusViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var requiresReauthentication: Bool = false
    @Published var user: JSON?
    @Published var pendingFlows: [JSON] = []

    private var cancellables = Set<AnyCancellable>()

    init(context: AuthContext) {
        context.$auth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] auth in
                self?.isAuthenticated = auth?.isAuthenticated ?? false
                self?.requiresReauthentication = context.requiresReauthentication
                self?.user = auth?.user
                self?.pendingFlows = context.pendingFlows
            }
            .store(in: &cancellables)
    }
}

// MARK: - Flow Helpers

/// Helper to determine navigation based on pending flows
@MainActor
public struct FlowNavigator {
    let authContext: AuthContext

    /// Get the path to navigate to based on pending flows
    func pathForPendingFlow() -> AuthRoute? {
        let flows = authContext.pendingFlows

        for flow in flows {
            guard let flowId = flow["id"].string,
                  let authFlow = AuthFlow(rawValue: flowId) else {
                continue
            }

            switch authFlow {
            case .verifyEmail:
                return .verifyEmail
            case .login:
                return .login
            case .loginByCode:
                return .confirmLoginCode
            case .signup:
                return .signup
            case .providerSignup:
                return .providerSignup
            case .mfaAuthenticate:
                return .mfaAuthenticate
            case .mfaReauthenticate:
                return .mfaReauthenticate
            case .reauthenticate:
                return .reauthenticate
            case .mfaTrust:
                return .mfaTrust
            case .mfaWebAuthnSignup:
                return .mfaWebAuthnSignup
            case .passwordResetByCode:
                return .resetPassword
            case .providerRedirect:
                return nil // Handled differently
            }
        }

        return nil
    }

    /// Check if MFA is required
    var mfaRequired: Bool {
        return authContext.isPending(flow: .mfaAuthenticate)
    }

    /// Check if reauthentication is required
    var reauthRequired: Bool {
        return authContext.isPending(flow: .reauthenticate) ||
               authContext.isPending(flow: .mfaReauthenticate)
    }
}

// MARK: - Auth Routes

public enum AuthRoute: Hashable {
    case login
    case signup
    case verifyEmail
    case confirmLoginCode
    case providerSignup
    case mfaAuthenticate
    case mfaReauthenticate
    case reauthenticate
    case mfaTrust
    case mfaWebAuthnSignup
    case resetPassword
    case requestPasswordReset
    case changePassword
    case changeEmail
    case mfaOverview
    case sessions
    case socialAccounts
}
