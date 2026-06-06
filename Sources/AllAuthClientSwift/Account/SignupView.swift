import Foundation
import SwiftUI
import SwiftyJSON

/// Sign up view
/// Equivalent to Signup.js in the React implementation
public struct SignupView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(title: "Create Account", subtitle: "Enter your details to get started.") {
            VStack(spacing: 16) {
                if authContext.emailAuthEnabled {
                    EmailField(text: $email, errors: response)
                }

                if authContext.usernameAuthEnabled {
                    UsernameField(text: $username, errors: response)
                }

                PasswordField("Password", text: $password, errors: response)

                PasswordField("Confirm Password", text: $passwordConfirm, errors: response, fieldName: "password2")

                // General errors
                FormErrors(errors: response)

                // Sign up button
                PrimaryButton(title: "Create Account", isLoading: isLoading) {
                    await signUp()
                }

                // Link to login
                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    LinkButton(title: "Sign in") {
                        navigationManager.navigate(to: .login)
                    }
                }
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() async {
        // Client-side validation
        if password != passwordConfirm {
            response = JSON(["errors": [["param": "password2", "message": "Passwords do not match"]]])
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let usernameParam = authContext.usernameAuthEnabled ? username : nil
            response = try await client.signUp(email: email, password: password, username: usernameParam)

            if response?.isSuccess == true {
                // Navigation handled by auth context observer
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SignupView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
