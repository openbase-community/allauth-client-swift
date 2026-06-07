import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Navigation Path Manager

/// Manages navigation state based on authentication flows
/// Equivalent to routing.js in the React implementation
@MainActor
public class AuthNavigationManager: ObservableObject {
    @Published public var path = NavigationPath()
    @Published public var currentRoute: AuthRoute?

    private let authContext: AuthContext

    public init(authContext: AuthContext) {
        self.authContext = authContext
    }

    /// Navigate to a specific route
    public func navigate(to route: AuthRoute) {
        currentRoute = route
        path.append(route)
    }

    /// Pop to root
    public func popToRoot() {
        path = NavigationPath()
        currentRoute = nil
    }

    /// Pop one level
    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Handle authentication state changes and navigate accordingly
    public func handleAuthChange(_ change: AuthChangeEvent) {
        switch change {
        case .loggedIn:
            // Navigate to home or dashboard
            popToRoot()

        case .loggedOut:
            // Navigate to login
            popToRoot()

        case .reauthenticated:
            // Successfully reauthenticated, return to previous flow
            popToRoot()

        case .reauthenticationRequired:
            // Navigate to reauthenticate
            if authContext.isPending(flow: .mfaReauthenticate) {
                navigate(to: .mfaReauthenticate)
            } else {
                navigate(to: .reauthenticate)
            }

        case .flowUpdated:
            // Check what flow needs attention
            handlePendingFlows()
        }
    }

    /// Navigate based on pending flows
    public func handlePendingFlows() {
        if let route = FlowNavigator(authContext: authContext).pathForPendingFlow() {
            navigate(to: route)
        }
    }

    /// Get the appropriate route for current auth state
    public func routeForCurrentState() -> AuthRoute? {
        if authContext.isAuthenticated {
            return nil // Go to main app
        }

        if authContext.requiresReauthentication {
            return FlowNavigator(authContext: authContext).pathForPendingFlow() ?? .reauthenticate
        }

        // Check pending flows
        return FlowNavigator(authContext: authContext).pathForPendingFlow()
    }
}

// MARK: - Route Views

/// Container view that handles authenticated vs anonymous routing
public struct AuthRoutingContainer<AuthenticatedContent: View, AnonymousContent: View>: View {
    @EnvironmentObject var authContext: AuthContext
    @StateObject private var navigationManager: AuthNavigationManager

    let authenticatedContent: () -> AuthenticatedContent
    let anonymousContent: () -> AnonymousContent

    public init(
        authContext: AuthContext,
        @ViewBuilder authenticated: @escaping () -> AuthenticatedContent,
        @ViewBuilder anonymous: @escaping () -> AnonymousContent
    ) {
        _navigationManager = StateObject(wrappedValue: AuthNavigationManager(authContext: authContext))
        authenticatedContent = authenticated
        anonymousContent = anonymous
    }

    public var body: some View {
        Group {
            if authContext.isLoading {
                ProgressView("Loading...")
            } else if authContext.isAuthenticated && !authContext.requiresReauthentication {
                authenticatedContent()
            } else {
                anonymousContent()
            }
        }
        .environmentObject(navigationManager)
        .onChange(of: authContext.lastAuthChange) { change in
            if let change = change {
                navigationManager.handleAuthChange(change)
            }
        }
    }
}

// MARK: - Auth Required Modifier

/// View modifier that redirects to login if not authenticated
public struct AuthRequiredModifier: ViewModifier {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    public func body(content: Content) -> some View {
        Group {
            if authContext.isAuthenticated {
                content
            } else {
                Color.clear
                    .onAppear {
                        navigationManager.navigate(to: .login)
                    }
            }
        }
    }
}

/// View modifier that redirects away if already authenticated
public struct AnonymousRequiredModifier: ViewModifier {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    public func body(content: Content) -> some View {
        Group {
            if !authContext.isAuthenticated {
                content
            } else {
                Color.clear
                    .onAppear {
                        navigationManager.popToRoot()
                    }
            }
        }
    }
}

public extension View {
    /// Require authentication to view this content
    func requiresAuth() -> some View {
        modifier(AuthRequiredModifier())
    }

    /// Require anonymous (not logged in) to view this content
    func requiresAnonymous() -> some View {
        modifier(AnonymousRequiredModifier())
    }
}

// MARK: - Flow-Based Navigation

/// View that automatically navigates based on pending auth flows
public struct FlowBasedNavigator: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    public var body: some View {
        Color.clear
            .onAppear {
                navigationManager.handlePendingFlows()
            }
            .onChange(of: authContext.pendingFlows.count) { _ in
                navigationManager.handlePendingFlows()
            }
    }
}
