import Foundation
import SwiftUI
import SwiftyJSON

/// Logout confirmation view
/// Equivalent to Logout.js in the React implementation
public struct LogoutView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var error: String?

    private let client = AllAuthClient.shared

    /// Called after a successful logout, before the view dismisses. Lets the
    /// host app reset device-local state so sign-out means a full reset.
    private let onLoggedOut: (() -> Void)?

    public init(onLoggedOut: (() -> Void)? = nil) {
        self.onLoggedOut = onLoggedOut
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Sign Out")
                .font(.title)
                .fontWeight(.bold)

            Text("Are you sure you want to sign out?")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let error = error {
                ErrorAlert(message: error) {
                    self.error = nil
                }
            }

            VStack(spacing: 12) {
                PrimaryButton(title: "Sign Out", isLoading: isLoading) {
                    await logout()
                }

                SecondaryButton(title: "Cancel", isLoading: false) {
                    dismiss()
                }
            }
        }
        .padding()
    }

    private func logout() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await client.logout()
            authContext.clearAuth()
            onLoggedOut?()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Simple logout button to embed in other views
public struct LogoutButton: View {
    @State private var showLogoutSheet = false

    public var body: some View {
        Button {
            showLogoutSheet = true
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .sheet(isPresented: $showLogoutSheet) {
            LogoutView()
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Preview

#Preview {
    LogoutView()
        .environmentObject(AuthContext.shared)
}
