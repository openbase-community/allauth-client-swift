import Foundation
import SwiftUI
import SwiftyJSON

/// Navigation bar component
/// Equivalent to NavBar.js in the React implementation
public struct NavBar: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    public var body: some View {
        HStack {
            // Logo/Title
            Text("AllAuth")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            // Auth-dependent content
            if authContext.isAuthenticated {
                authenticatedMenu
            } else {
                unauthenticatedMenu
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    var authenticatedMenu: some View {
        Menu {
            Button {
                navigationManager.navigate(to: .changeEmail)
            } label: {
                Label("Email Addresses", systemImage: "envelope")
            }

            Button {
                navigationManager.navigate(to: .changePassword)
            } label: {
                Label("Change Password", systemImage: "lock")
            }

            if authContext.mfaEnabled {
                Button {
                    navigationManager.navigate(to: .mfaOverview)
                } label: {
                    Label("Two-Factor Auth", systemImage: "shield.checkered")
                }
            }

            Button {
                navigationManager.navigate(to: .sessions)
            } label: {
                Label("Sessions", systemImage: "desktopcomputer")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    _ = try? await AllAuthClient.shared.logout()
                    authContext.clearAuth()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)

                if let email = authContext.user?["email"].string {
                    Text(email)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }

    var unauthenticatedMenu: some View {
        HStack(spacing: 16) {
            Button("Sign In") {
                navigationManager.navigate(to: .login)
            }

            if authContext.signupAllowed {
                Button("Sign Up") {
                    navigationManager.navigate(to: .signup)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Settings view
public struct SettingsView: View {
    @EnvironmentObject var authContext: AuthContext

    public var body: some View {
        List {
            Section("Account") {
                NavigationLink {
                    ChangeEmailView()
                } label: {
                    Label("Email Addresses", systemImage: "envelope")
                }

                NavigationLink {
                    ChangePasswordView()
                } label: {
                    Label("Change Password", systemImage: "lock")
                }
            }

            Section("Security") {
                if authContext.mfaEnabled {
                    NavigationLink {
                        MFAOverviewView()
                    } label: {
                        Label("Two-Factor Authentication", systemImage: "shield.checkered")
                    }
                }

                NavigationLink {
                    SessionsView()
                } label: {
                    Label("Active Sessions", systemImage: "desktopcomputer")
                }

                if !authContext.socialProviders.isEmpty {
                    NavigationLink {
                        ManageProvidersView()
                    } label: {
                        Label("Connected Accounts", systemImage: "person.2")
                    }
                }
            }

            Section {
                LogoutButton()
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Preview

#Preview("Authenticated") {
    NavBar()
        .environmentObject(AuthContext.shared)
        .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
}
