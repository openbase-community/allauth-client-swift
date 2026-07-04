import Foundation
import SwiftUI
import SwiftyJSON

/// Change password view
/// Equivalent to ChangePassword.js in the React implementation
public struct ChangePasswordView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirm = ""
    @State private var isLoading = false
    @State private var response: JSON?
    @State private var showSuccess = false

    private let client = AllAuthClient.shared

    /// Whether current password is required (user has usable password)
    var requiresCurrentPassword: Bool {
        return authContext.user?["has_usable_password"].bool ?? true
    }

    public init() {}

    public var body: some View {
        AuthForm(
            title: "Change Password",
            subtitle: requiresCurrentPassword
                ? "Enter your current password and choose a new one."
                : "Set a password for your account."
        ) {
            VStack(spacing: 16) {
                if requiresCurrentPassword {
                    PasswordField(
                        "Current Password",
                        text: $currentPassword,
                        errors: response,
                        fieldName: "current_password"
                    )
                }

                PasswordField(
                    "New Password",
                    text: $newPassword,
                    errors: response,
                    fieldName: "new_password"
                )

                PasswordField(
                    "Confirm New Password",
                    text: $newPasswordConfirm,
                    errors: response,
                    fieldName: "new_password2"
                )

                // General errors
                FormErrors(errors: response)

                if showSuccess {
                    SuccessAlert(message: "Password changed successfully") {
                        showSuccess = false
                    }
                }

                PrimaryButton(title: "Change Password", isLoading: isLoading) {
                    await changePassword()
                }
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changePassword() async {
        // Client-side validation
        if newPassword != newPasswordConfirm {
            response = JSON(["errors": [["param": "new_password2", "message": "Passwords do not match"]]])
            return
        }

        response = await performRequest(loading: $isLoading, context: "change password") {
            let currentPwd = requiresCurrentPassword ? currentPassword : nil
            return try await client.changePassword(currentPassword: currentPwd, newPassword: newPassword)
        }

        if response?.isSuccess == true {
            showSuccess = true
            currentPassword = ""
            newPassword = ""
            newPasswordConfirm = ""
            response = nil
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChangePasswordView()
            .environmentObject(AuthContext.shared)
    }
}
