import Foundation
import SwiftUI
import SwiftyJSON

/// Email address management view
/// Equivalent to ChangeEmail.js in the React implementation
public struct ChangeEmailView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var emailAddresses: [JSON] = []
    @State private var newEmail = ""
    @State private var isLoading = false
    @State private var isAddingEmail = false
    @State private var response: JSON?
    @State private var showSuccess = false
    @State private var successMessage = ""

    private let client = AllAuthClient.shared

    public init() {}

    public var body: some View {
        List {
            // Existing email addresses
            Section("Your Email Addresses") {
                if emailAddresses.isEmpty && !isLoading {
                    Text("No email addresses")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(emailAddresses.enumerated()), id: \.offset) { _, email in
                        EmailAddressRow(
                            email: email,
                            onSetPrimary: { await setPrimary(email: email["email"].stringValue) },
                            onRequestVerification: { await requestVerification(email: email["email"].stringValue) },
                            onDelete: { await deleteEmail(email: email["email"].stringValue) }
                        )
                    }
                }
            }

            // Add new email
            Section("Add Email Address") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("New email address", text: $newEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    FormErrors(errors: response, field: "email")

                    PrimaryButton(title: "Add Email", isLoading: isAddingEmail) {
                        await addEmail()
                    }
                    .disabled(newEmail.isEmpty)
                }
                .padding(.vertical, 8)
            }

            if showSuccess {
                Section {
                    SuccessAlert(message: successMessage) {
                        showSuccess = false
                    }
                }
            }
        }
        .navigationTitle("Email Addresses")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadEmails()
        }
        .task {
            await loadEmails()
        }
    }

    private func loadEmails() async {
        let result = await performRequest(loading: $isLoading, context: "load emails") {
            try await client.getEmailAddresses()
        }
        if result.isSuccess {
            emailAddresses = result["data"].arrayValue
        }
    }

    private func addEmail() async {
        response = await performRequest(loading: $isAddingEmail, context: "add email") {
            try await client.addEmailAddress(email: newEmail)
        }

        if response?.isSuccess == true {
            newEmail = ""
            response = nil
            successMessage = "Email address added. Please check your inbox for verification."
            showSuccess = true
            await loadEmails()
        }
    }

    private func setPrimary(email: String) async {
        do {
            let result = try await client.setPrimaryEmailAddress(email: email)
            if result.isSuccess {
                successMessage = "Primary email updated"
                showSuccess = true
                await loadEmails()
            }
        } catch {
            AuthDiagnostics.log(
                "ChangeEmailView",
                "failed to set primary email",
                metadata: ["error": "\(error)"]
            )
        }
    }

    private func requestVerification(email: String) async {
        do {
            let result = try await client.requestEmailVerification(email: email)
            if result.isSuccess {
                successMessage = "Verification email sent"
                showSuccess = true
            }
        } catch {
            AuthDiagnostics.log(
                "ChangeEmailView",
                "failed to request verification",
                metadata: ["error": "\(error)"]
            )
        }
    }

    private func deleteEmail(email: String) async {
        do {
            let result = try await client.deleteEmailAddress(email: email)
            if result.isSuccess {
                successMessage = "Email address removed"
                showSuccess = true
                await loadEmails()
            }
        } catch {
            AuthDiagnostics.log(
                "ChangeEmailView",
                "failed to delete email",
                metadata: ["error": "\(error)"]
            )
        }
    }
}

/// Row for displaying an email address
struct EmailAddressRow: View {
    let email: JSON
    let onSetPrimary: () async -> Void
    let onRequestVerification: () async -> Void
    let onDelete: () async -> Void

    @State private var showActions = false

    var emailString: String { email["email"].stringValue }
    var isPrimary: Bool { email["primary"].boolValue }
    var isVerified: Bool { email["verified"].boolValue }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(emailString)
                    .font(.body)

                HStack(spacing: 8) {
                    if isPrimary {
                        Label("Primary", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if isVerified {
                        Label("Verified", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Unverified", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()

            Button {
                showActions = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .confirmationDialog("Email Actions", isPresented: $showActions) {
                if !isPrimary && isVerified {
                    Button("Set as Primary") {
                        Task { await onSetPrimary() }
                    }
                }

                if !isVerified {
                    Button("Resend Verification") {
                        Task { await onRequestVerification() }
                    }
                }

                if !isPrimary {
                    Button("Remove", role: .destructive) {
                        Task { await onDelete() }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChangeEmailView()
            .environmentObject(AuthContext.shared)
    }
}
